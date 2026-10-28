"""Independent pinned Python oracles -> golden JSON and public-API MoonBit tests.
Run in the sibling venv. No MoonBit implementation is read to calculate truth.
"""
import io, itertools, json, pathlib, copy, hashlib, re
import Bio, dendropy
from Bio import Phylo, AlignIO
from Bio.Align import MultipleSeqAlignment
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord
from Bio.Phylo.TreeConstruction import ParsimonyScorer
from dendropy.calculate import treecompare
from dendropy.model.parsimony import fitch_down_pass

HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parent if HERE.name=='verification' else HERE.parents[3]/'projects'/'moonbit-phylo'
DATA=ROOT/'testdata' if HERE.name=='verification' else HERE
real=DATA/('fiddler-42.newick' if HERE.name=='verification' else 'real-tree.newick')
original=DATA/'Fiddler_complete.nex'
if original.exists():
    realtree=Phylo.read(original,'nexus')
    stream=io.StringIO();Phylo.write(realtree,stream,'newick',format_branch_length='%0.17g')
    text=stream.getvalue().strip()
    for leaf in realtree.get_terminals():
        text=re.sub(r'(?<=[(,])'+re.escape(leaf.name)+r'(?=:)',lambda _:"'"+leaf.name.replace("'","''")+"'",text)
    real.write_text(text+'\n',encoding='utf-8')
def q(s): return json.dumps(s,ensure_ascii=False)
def arr(xs): return '['+', '.join(q(x) for x in xs)+']'
def splits(t,rooted):
    t.encode_bipartitions()
    n=len(t.taxon_namespace); out=set()
    for bp in t.bipartition_encoding:
        mask=bp.split_bitmask; k=mask.bit_count()
        if (1<k<n) if rooted else (1<k<n-1):
            out.add(tuple(x.label for i,x in enumerate(t.taxon_namespace) if mask & (1<<i)))
    return sorted(out)
def rf(a,b,rooted):
    labels=sorted(x.name for x in Phylo.read(io.StringIO(a),'newick').get_terminals())
    ns=dendropy.TaxonNamespace(labels)
    kw=dict(schema='newick',rooting='force-rooted' if rooted else 'force-unrooted',taxon_namespace=ns)
    ta=dendropy.Tree.get(data=a,**kw);tb=dendropy.Tree.get(data=b,**kw)
    sa=splits(ta,rooted);sb=splits(tb,rooted)
    d=treecompare.symmetric_difference(ta,tb)
    left=sorted(set(sa)-set(sb));right=sorted(set(sb)-set(sa));shared=sorted(set(sa)&set(sb))
    assert d==len(left)+len(right)
    return dict(distance=d,shared=shared,left=left,right=right)

fixtures=[]; tests=[]
pairs=[
 ('root-matters','((A,B),(C,D));','(A,(B,(C,D)));'),
 ('rotation','((A,B),(C,D));','((D,C),(B,A));'),
 ('different-quartet','((A,B),(C,D));','((A,C),(B,D));'),
 ('lexical-not-shortlex',"(('A_long',B),(C,D));","(('A_long',C),(B,D));"),
 ('unresolved','(A,B,C,D);','((A,B),(C,D));'),
 ('three-taxa','((A,B),C);','(A,(B,C));'),
 ('single','A;','A;'),
 ('unary','(((A,B)),(C,D));','((A,B),(C,D));'),
 ('delimiters',"(('a|b','c,d'),('e:f','g h'));","(('a|b','e:f'),('c,d','g h'));"),
 ('over64','('+','.join('T%02d'%i for i in range(70))+');','(('+','.join('T%02d'%i for i in range(35))+'),('+','.join('T%02d'%i for i in range(35,70))+'));'),
]
for name,a,b in pairs:
    row=dict(kind='rf',name=name,a=a,b=b,rooted=rf(a,b,True),unrooted=rf(a,b,False));fixtures.append(row)
    body=[f'  let a = read({q(a)})',f'  let b = read({q(b)})']
    for mode in ('rooted','unrooted'):
        r=row[mode];body += [f'  let r = a.rf_distance_{mode}(b).unwrap()',f'  assert_eq(r.distance, {r["distance"]})']
        for field,key in [('shared','shared'),('only_left','left'),('only_right','right')]:
            val='['+', '.join(arr(x) for x in r[key])+']'
            body.append(f'  assert_eq(r.{field}, {val})')
    tests.append('///|\ntest '+q('oracle RF '+name)+' {\n'+'\n'.join(body)+'\n}')

def brute(tree,traits):
    nodes=list(tree.find_clades(order='preorder'));internal=[x for x in nodes if not x.is_terminal()]
    states=sorted(set(traits.values())-{'?'}) or ['0'];best=10**9
    for combo in itertools.product(states,repeat=len(internal)):
        mapping={id(x):s for x,s in zip(internal,combo)}
        for leaf in tree.get_terminals():mapping[id(leaf)]=traits[leaf.name]
        # Missing leaves can always copy their parent without changing topology.
        cost=0
        for x in internal:
            for c in x.clades:
                v=mapping[id(c)]
                if v!='?' and v!=mapping[id(x)]:cost+=1
        best=min(best,cost)
    return 0 if not internal else best

trees=['A;','(A,B);','((A,B),(C,D));','(A,(B,(C,D)));','((A,(B,C)),(D,(E,F)));']
if real.exists():trees.append(real.read_text().strip())
for ix,s in enumerate(trees):
    bio=Phylo.read(io.StringIO(s),'newick');bio.rooted=True
    names=sorted(x.name for x in bio.get_terminals())
    for missing in (False,True):
        traits={t:('?' if missing and i%3==0 else str(i%2)) for i,t in enumerate(names)}
        dt=dendropy.Tree.get(data=s,schema='newick',rooting='force-rooted')
        alphabet=set(traits.values())-{'?'} or {'0'}
        m={t:[alphabet if traits[t.label]=='?' else {traits[t.label]}] for t in dt.taxon_namespace}
        dscore=fitch_down_pass(dt.postorder_node_iter(),taxon_state_sets_map=m)
        brute_score=brute(bio,traits) if len(names)<=6 else None
        exact=dscore if brute_score is None else brute_score
        if brute_score is not None:assert dscore==exact
        bscore=None
        if not missing:
            alignment=MultipleSeqAlignment([SeqRecord(Seq(traits[t]),id=t) for t in names])
            bscore=ParsimonyScorer().get_score(copy.deepcopy(bio),alignment);assert bscore==exact
        fixtures.append(dict(kind='fitch',newick=s,traits=traits,dendropy=dscore,brute=brute_score,biopython=bscore))
        mt='{ '+', '.join(q(t)+": '"+v+"'" for t,v in traits.items())+' }'
        tests.append('///|\ntest '+q(f'oracle Fitch {ix} missing={missing}')+' {\n'+f'  let t = read({q(s)})\n  let traits : Map[String, Char] = {mt}\n  let r = t.fitch_parsimony(traits).unwrap()\n  assert_eq(r.score, {exact})\n  assert_eq(r.changed_edges.length(), r.score)\n  check_assignment(t, r)\n  check_observations(t, r, traits)\n'+'}')

distances=['((A:1,B:2):3,(C:4,D:5):6):99;','(A:0,(B:0,(C:2,D:4):1):3);','((A:0.1,B:0.2):0.3,C:0.4);']
if real.exists():distances.append(real.read_text().strip())
for ix,s in enumerate(distances):
    t=Phylo.read(io.StringIO(s),'newick'); names=sorted(x.name for x in t.get_terminals())
    # Small cases full matrix, real sample first/last/spread pairs, not thousands of mirrored assertions.
    chosen=names if len(names)<10 else [names[i] for i in [0,1,len(names)//3,len(names)//2,-2,-1]]
    pairs=[(a,b,t.distance(a,b)) for a in chosen for b in chosen]
    positive=max(v for _,_,v in pairs)>0
    midpoint=copy.deepcopy(t)
    if positive:midpoint.root_at_midpoint()
    retain=chosen[::2] if len(chosen)>2 else chosen
    pruned=copy.deepcopy(t)
    for leaf in list(pruned.get_terminals()):
        if leaf.name not in retain:pruned.prune(leaf)
    fixtures.append(dict(kind='distance-transform',newick=s,pairs=pairs,retain=retain,source='CC0 fiddler-claw real data' if ix==3 else 'authored'))
    body=[f'  let t = read({q(s)})','  let reroot = t.midpoint_root().unwrap()','  assert_eq(t.rf_distance_unrooted(reroot.tree).unwrap().distance, 0)',f'  let pruned = t.prune({arr(retain)}).unwrap()',f'  assert_eq(pruned.tree.taxa(), {arr(sorted(retain))})','  check_mapping(t, reroot)','  check_mapping(t, pruned)']
    for a,b,v in pairs:
        body.append(f'  near(t.patristic_distance({q(a)}, {q(b)}).unwrap(), {v!r})')
        body.append(f'  near(reroot.tree.patristic_distance({q(a)}, {q(b)}).unwrap(), {midpoint.distance(a,b)!r})')
        if a in retain and b in retain:body.append(f'  near(pruned.tree.patristic_distance({q(a)}, {q(b)}).unwrap(), {pruned.distance(a,b)!r})')
    tests.append('///|\ntest '+q(f'oracle distances transforms {ix}')+' {\n'+'\n'.join(body)+'\n}')

out={'versions':{'biopython':Bio.__version__,'dendropy':dendropy.__version__},'cases':fixtures,'independent_methods':['DendroPy exact bipartitions/RF/Fitch','Biopython path distances/prune/midpoint/Fitch known states','exhaustive internal-state assignment (not Fitch)']}
(DATA/'golden.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
(ROOT/'oracle_test.mbt').write_text('// Generated by implementation-03/reference/generate.py from independent oracles.\n'+'\n\n'.join(tests)+'\n',encoding='utf-8')
print(json.dumps({'versions':out['versions'],'fixture_cases':len(fixtures),'generated_tests':len(tests),'golden_sha256':hashlib.sha256((DATA/'golden.json').read_bytes()).hexdigest(),'real_data_used':real.exists()}))
