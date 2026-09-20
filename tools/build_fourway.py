#!/usr/bin/env python3
"""Build the three native participants without modifying their hash algorithms."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LEAN_COMMIT = '4310886800df03d5850ae5aed170c5611548f921'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--work-dir', type=Path, default=ROOT/'.bench-fourway')
    for name, default in [('bend','bend'),('go','go'),('lake','lake'),('cc','cc')]:
        p.add_argument('--'+name, default=default)
    args=p.parse_args(); work=args.work_dir.resolve(); work.mkdir(parents=True,exist_ok=True)
    commands=[]
    def run(cmd):
        commands.append(cmd)
        subprocess.run(cmd,check=True,cwd=ROOT)
    run([args.bend,str(ROOT/'benchmarks/packed_driver.bend'),'-o',str(work/'bend.c')])
    run([args.cc,'-O3','-march=native','-std=c11',str(work/'bend.c'),'-lpthread','-lm','-o',str(work/'bend')])
    run([args.go,'build','-o',str(work/'go'),str(ROOT/'benchmarks/fourway/main.go')])
    lean=work/'LeanSha256'
    if not lean.exists():
        run(['git','clone','https://github.com/etheorem/LeanSha256.git',str(lean)])
    current=subprocess.check_output(['git','-C',str(lean),'rev-parse','HEAD'],text=True).strip()
    if current != LEAN_COMMIT:
        run(['git','-C',str(lean),'checkout','--detach',LEAN_COMMIT])
    run(['git','-C',str(lean),'diff','--exit-code',LEAN_COMMIT,'--','LeanSha256/Core.lean','LeanSha256.lean'])
    shutil.copyfile(ROOT/'benchmarks/fourway/Bench.lean',lean/'Bench.lean')
    lakefile=lean/'lakefile.toml';text=lakefile.read_text()
    if 'name = "shaBench"' not in text:
        lakefile.write_text(text+'\n[[lean_exe]]\nname = "shaBench"\nroot = "Bench"\n')
    lean_version=subprocess.check_output([args.lake,'-d',str(lean),'env','lean','--version'],text=True).strip()
    if 'version 4.29.1,' not in lean_version:
        raise RuntimeError(f'Expected Lean 4.29.1, got {lean_version}')
    run([args.lake,'-d',str(lean),'build','shaBench'])
    record={'commands':commands,'lean_commit':LEAN_COMMIT,'lean_version':lean_version,
            'bend_version':subprocess.check_output([args.bend,'--version'],text=True).strip(),
            'go_version':subprocess.check_output([args.go,'version'],text=True).strip(),
            'c_compiler':subprocess.check_output([args.cc,'--version'],text=True).splitlines()[0],
            'bend_c_sha256':hashlib.sha256((work/'bend.c').read_bytes()).hexdigest()}
    (work/'build.json').write_text(json.dumps(record,indent=2)+'\n')
    print('Build ready in',work)


if __name__=='__main__':
    main()
