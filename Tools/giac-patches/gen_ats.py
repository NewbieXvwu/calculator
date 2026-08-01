#!/usr/bin/env python3
import re, subprocess, os

OBJ = '/tmp/giac-fork/symcheck/obj'
STUB = '/tmp/giac-fork/giac-2.1.0/src/giac_stubs.cc'
stub_src = open(STUB).read()

# existing at_ names already defined in stub
existing = set(re.findall(r'define_unary_function_ptr5\(at_([A-Za-z0-9_]+),', stub_src))

# module -> (object files, stub ptr macro, insert-after marker)
modules = [
 ('rpn',      ['rpn'],             'STUB_RPN_PTR',     'define_unary_function_ptr5(at_tests, alias_at_tests, STUB_RPN_PTR, 0, 0);'),
 ('ti89',     ['ti89'],            'STUB_TI89_PTR',    'define_unary_function_ptr5(at_zeros, alias_at_zeros, STUB_TI89_PTR, 0, 0);'),
 ('maple',    ['maple'],           'STUB_MAPLE_PTR',   'define_unary_function_ptr5(at_trunc, alias_at_trunc, STUB_MAPLE_PTR, 0, 0);'),
 ('moyal',    ['moyal'],           'STUB_PROBA_PTR',   'define_unary_function_ptr5(at_white, alias_at_white, STUB_PROBA_PTR, 0, 0);'),
 ('proba',    ['proba'],           'STUB_PROBA_PTR',   'define_unary_function_ptr5(at_white, alias_at_white, STUB_PROBA_PTR, 0, 0);'),
 ('cocoa',    ['cocoa','pari'],    'STUB_EXTLIB_PTR',  'bool pari_polroots(const vecteur & p,vecteur & res,longlong prec,GIAC_CONTEXT){ (void)p;(void)prec; res.clear(); return false; }'),
 ('graphtheory',['graphtheory'],   'STUB_GRAPH_PTR',   'define_unary_function_ptr5(at_trail, alias_at_trail, STUB_GRAPH_PTR, 0, 0);'),
 ('isom',     ['isom'],            'STUB_ISOM_PTR',    'vecteur mkisom(const gen & n,int b,GIAC_CONTEXT){ (void)n;(void)b; return vecteur(); }'),
 ('mathml',   ['mathml'],          'STUB_MATHML_PTR',  'define_unary_function_ptr5(at_latex, alias_at_latex, &__STUB_LATEX, 0, true);'),
 ('tex',      ['tex'],             'STUB_MATHML_PTR',  'define_unary_function_ptr5(at_latex, alias_at_latex, &__STUB_LATEX, 0, true);'),
 ('markup',   ['markup'],          'STUB_MATHML_PTR',  'define_unary_function_ptr5(at_latex, alias_at_latex, &__STUB_LATEX, 0, true);'),
 ('help',     ['help'],            'STUB_HELP_PTR',    'std::string html_help_init(const char * arg,int language,bool verbose,bool force_rebuild){ (void)arg;(void)language;(void)verbose;(void)force_rebuild; return std::string(); }'),
 ('desolve',  ['desolve'],         'STUB_DESOLVE_PTR', 'bool separate_variables(const gen & f,const gen & x,const gen & y,gen & xfact,gen & yfact,GIAC_CONTEXT){ (void)f;(void)x;(void)y; xfact=yfact=0; return false; }'),
 ('quater',   ['quater'],          'STUB_QUATER_PTR',  None),
 ('signalprocessing',['signalprocessing'],'STUB_SIGNAL_PTR','define_unary_function_ptr5(at_train, alias_at_train, STUB_SIGNAL_PTR, 0, 0);'),
 ('plot3d',   ['plot3d'],          'STUB_PLOT3D_PTR',  None),
]

def extract_ats(objfiles):
    ats = set()
    for o in objfiles:
        p = os.path.join(OBJ, o + '.o')
        if not os.path.exists(p):
            continue
        out = subprocess.run(['nm','-g','--defined-only',p], capture_output=True, text=True).stdout
        for m in re.finditer(r'_ZN4giac[0-9]+at_([A-Za-z0-9_]+)E', out):
            ats.add(m.group(1))
    return ats

lines = []
for mod, objfiles, ptr, marker in modules:
    ats = sorted(extract_ats(objfiles) - existing)
    if not ats:
        print(f"{mod}: 无缺失 (共 {len(extract_ats(objfiles))})")
        continue
    print(f"{mod}: 缺失 {len(ats)} 个")
    if ptr == 'STUB_MATHML_PTR':
        block = ''.join(f'define_unary_function_ptr5(at_{a}, alias_at_{a}, &__STUB_MATHML, 0, 0);\n' for a in ats)
    else:
        block = ''.join(f'define_unary_function_ptr5(at_{a}, alias_at_{a}, {ptr}, 0, 0);\n' for a in ats)
    lines.append((mod, marker, block, ats))
    existing |= set(ats)

# apply insertions
src = open(STUB).read()
for mod, marker, block, ats in lines:
    if marker is None:
        print(f"{mod}: 无插入锚点，跳过")
        continue
    if marker not in src:
        print(f"{mod}: 锚点未找到: {marker[:60]}")
        continue
    src = src.replace(marker, marker + '\n' + block, 1)
open(STUB, 'w').write(src)
print("完成")
