"""Run actual NJ consumers against hand-tree/Fraction binary64 expectations.

The fixture and its independent generator contain no NJ implementation. No
fixture is regenerated during validation. All expected path/branch comparisons
in this suite are exact binary64 bits, including the small mixed-scale limbs.
"""
from pathlib import Path
import argparse,hashlib,json,math,os,shutil,struct,subprocess

ROOT=Path(__file__).resolve().parents[1]


def bits(x):
    return f'{struct.unpack(">Q",struct.pack(">d",float(x)))[0]:016x}'


def facts(payload):
    nodes={n['id']:n for n in payload['nodes']}
    taxa=payload['fitted']['taxa']
    def descendants(index):
        node=nodes[index]
        return [node['label']] if not node['children'] else [t for c in node['children'] for t in descendants(c)]
    result={}
    for node in nodes.values():
        if 'parent' not in node:continue
        length=node['length'];assert math.isfinite(length) and length>=0
        side=sorted(descendants(node['id']));other=sorted(set(taxa)-set(side));key=tuple(min((side,other),key=lambda x:(len(x),x)))
        assert key not in result, 'Unexpected degree-two representation in these >=3-tip fixtures'
        result[key]=bits(length)
    return result


def constant_error(value):
    raise AssertionError('Nonfinite JSON output: '+value)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--artifact-dir',required=True)
    parser.add_argument('--moonrun',required=True)
    parser.add_argument('--output',required=True)
    parser.add_argument('--compare-controls')
    args=parser.parse_args()
    fixture=ROOT/'verification/nj_range_cases.json'
    cases=json.loads(fixture.read_text(encoding='utf-8'))['cases']
    output=Path(args.output);output.mkdir(parents=True,exist_ok=True)
    runs=[]
    for case in cases:
        (output/(case['name']+'.input.json')).write_text(json.dumps(case['matrix'],separators=(',',':'),allow_nan=False)+'\n',encoding='utf-8')
    for target in ['js','wasm-gc']:
        artifact=Path(args.artifact_dir)/target/'debug/build/cmd/nj_matrix'/('nj_matrix.js' if target=='js' else 'nj_matrix.wasm')
        runner=shutil.which('node') if target=='js' else args.moonrun
        assert artifact.is_file() and runner
        artifact_sha=hashlib.sha256(artifact.read_bytes()).hexdigest()
        for case in cases:
            env=os.environ.copy();env['PHYLO_NJ_MATRIX']=json.dumps(case['matrix'],separators=(',',':'),allow_nan=False);env.pop('PHYLO_NJ_REFERENCE',None)
            if 'newick' in case:env['PHYLO_NJ_REFERENCE']=case['newick']
            q=subprocess.run([runner,str(artifact)],env=env,capture_output=True,timeout=30)
            stem=target+'-'+case['name'];(output/(stem+'.stdout.json')).write_bytes(q.stdout);(output/(stem+'.stderr.txt')).write_bytes(q.stderr)
            assert q.returncode==0,(stem,q.returncode)
            value=json.loads(q.stdout,parse_constant=constant_error)
            if case['expected']=='success':
                assert value['ok'] is True and value['rooting']=='unrooted' and value['newick'].startswith('[&U]'),(stem,value)
                assert value['comparison']['distance']==0
                assert value['input']==case['matrix']
                actual_bits=[[bits(v) for v in row] for row in value['fitted']['values']]
                assert actual_bits==case['fitted_bits'],(stem,actual_bits,case['fitted_bits'])
                assert facts(value)=={tuple(e['taxa']):e['length_bits'] for e in case['branches']},(stem,facts(value),case['branches'])
                assert value['max_abs_residual']==0 and value['rms_residual']==0
            else:
                assert value['ok'] is False and value['error']==case['expected'] and 'newick' not in value,(stem,value)
                if 'stage' in case:assert value['stage']==case['stage'],(stem,value)
                if case['expected']=='negative_limb':
                    assert value['taxa']==case['taxa'] and bits(value['length'])==case['length_bits']
                    assert value['length_bits']==str(int(case['length_bits'],16))
            runs.append({'target':target,'case':case['name'],'artifact_sha256':artifact_sha,'ok':True})
        if args.compare_controls:
            control=Path(args.compare_controls)
            for source in sorted(control.glob('*.input.json')):
                name=source.name.removesuffix('.input.json');env=os.environ.copy();env['PHYLO_NJ_MATRIX']=source.read_text(encoding='utf-8');env.pop('PHYLO_NJ_REFERENCE',None)
                q=subprocess.run([runner,str(artifact)],env=env,capture_output=True,timeout=30)
                (output/(target+'-control-'+name+'.stdout.json')).write_bytes(q.stdout)
                assert q.returncode==0
                before=json.loads((control/(target+'-'+name+'.stdout.json')).read_text(encoding='utf-8'))
                after=json.loads(q.stdout,parse_constant=constant_error)
                assert after==before,(target,name,'Legacy result changed')
                # The serialized Newick and every numeric token also stay equal.
                assert after['newick']==before['newick']
                runs.append({'target':target,'control':name,'artifact_sha256':artifact_sha,'legacy_output_equal':True})
    result={'status':'passed','oracle':'Saved hand trees and Fraction(actual binary64), exact bits',
            'fixture_sha256':hashlib.sha256(fixture.read_bytes()).hexdigest(),'runs':runs,'count':len(runs)}
    (output/'RESULT.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':'passed','range_consumer_calls':len(runs),'output':str(output)}))


if __name__=='__main__':main()
