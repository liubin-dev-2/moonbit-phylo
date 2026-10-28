"""Independent preimplementation expectations from hand-specified trees.

No NJ recurrence is implemented here. Fraction uses the actual binary64 input
values; tree paths are exact sums of independently specified branch values.
"""
from pathlib import Path
from fractions import Fraction as F
import json,math,struct


def bits(x):
    return f'{struct.unpack(">Q",struct.pack(">d",x))[0]:016x}'


def power(exponent):
    return math.ldexp(1.,exponent)


def adjacency(edges):
    out={}
    for a,b,d in edges:
        out.setdefault(a,[]).append((b,F.from_float(d)))
        out.setdefault(b,[]).append((a,F.from_float(d)))
    return out


def path(graph,a,b,parent=None):
    if a==b:return F(0)
    for node,length in graph[a]:
        if node!=parent:
            result=path(graph,node,b,a)
            if result is not None:return length+result
    return None


def branch_facts(taxa,edges):
    graph=adjacency(edges);facts=[]
    def leaves(node,blocked):
        names=[node] if node in taxa else []
        for nxt,_ in graph[node]:
            if nxt!=blocked:names+=leaves(nxt,node)
        return names
    for a,b,d in edges:
        left=sorted(leaves(a,b));right=sorted(set(taxa)-set(left))
        side=min((left,right),key=lambda v:(len(v),v))
        facts.append({'taxa':side,'length':d,'length_bits':bits(d),'exact_stored_length':str(F.from_float(d))})
    return sorted(facts,key=lambda v:v['taxa'])


def tree_case(name,taxa,edges,newick,matrix=None):
    graph=adjacency(edges)
    fitted=[[float(path(graph,a,b)) for b in taxa] for a in taxa]
    values=matrix if matrix is not None else fitted
    assert all(math.isfinite(v) and v>=0 for row in values for v in row)
    return {'name':name,'matrix':{'taxa':taxa,'values':values},'expected':'success','newick':newick,
            'branches':branch_facts(taxa,edges),'fitted':fitted,
            'fitted_bits':[[bits(v) for v in row] for row in fitted],
            'exact_input_row_sums':[str(sum(map(F.from_float,row))) for row in values]}


def cases():
    u=power(1019)
    edges=[('A','I',2*u),('B','I',3*u),('I','R',13*u),('C','R',5*u),('R','J',8*u),('D','J',6*u),('E','J',7*u)]
    five=tree_case('large_five',list('ABCDE'),edges,
                   f'[&U]((A:{2*u:.17g},B:{3*u:.17g}):{13*u:.17g},C:{5*u:.17g},(D:{6*u:.17g},E:{7*u:.17g}):{8*u:.17g});')
    five['independent_reason']='Positive branches 2,3,5,6,7,13,8 times 2^1019; longest input path 31*2^1019 is finite, row sums exceed binary64 maximum.'
    maximum=float.fromhex('0x1.fffffffffffffp+1023');half=maximum/2
    star=tree_case('maximum_star3',list('ABC'),[(x,'R',half) for x in 'ABC'],
                   '[&U]('+','.join(f'{x}:{half:.17g}' for x in 'ABC')+');')
    large=power(1023);tiny=power(-1000)
    mixed_values=[[0.,2*tiny,large,large],[2*tiny,0.,large,large],[large,large,0.,large/2],[large,large,large/2,0.]]
    # Exact input split equations give A=B=tiny, C=D=large/4,
    # internal=3*large/4-tiny. Round this one branch once to binary64.
    internal=float(F.from_float(large)*F(3,4)-F.from_float(tiny))
    mixed=tree_case('mixed_normal',list('ABCD'),[('A','I',tiny),('B','I',tiny),('I','R',internal),('C','R',large/4),('D','R',large/4)],
                    f'[&U]((A:{tiny:.17g},B:{tiny:.17g}):{internal:.17g},C:{large/4:.17g},D:{large/4:.17g});',mixed_values)
    mixed['exact_internal_before_rounding']=str(F.from_float(large)*F(3,4)-F.from_float(tiny))
    assert mixed['fitted']==mixed_values
    least=power(-1074)
    unsafe={'name':'mixed_subnormal','matrix':{'taxa':list('ABCD'),'values':[[0.,2*least,large,large],[2*least,0.,large,large],[large,large,0.,large/2],[large,large,large/2,0.]]},
            'expected':'numeric_overflow','stage':'scale_input_range',
            'independent_reason':'The positive AB distance is 2^-1073. A 2^-8 conversion would erase it; an explicit range error is required instead of a zero-distance success.'}
    ab=float.fromhex('0x1.0000000000001p-1014')
    gradual={'name':'mixed_intermediate','matrix':{'taxa':list('ABCD'),'values':[[0.,ab,large,large],[ab,0.,large,large],[large,large,0.,large/2],[large,large,large/2,0.]]},
             'expected':'numeric_overflow','stage':'limb_half_scaled_range',
             'exact_AB_limb_in_input_units':str(F.from_float(ab)/2),
             'independent_reason':'AB converts exactly to normal 0x1.0000000000001p-1022, but halving in scaled units rounds away its low bit. The original-unit half is representable; reject this conservative fallback range instead of altering that limb.'}
    assert (ab/256)*256==ab and F.from_float((ab/256)/2)*256!=F.from_float(ab)/2
    s=power(1021)
    negative={'name':'large_negative','matrix':{'taxa':list('ABCD'),'values':[[0.,s,s,s],[s,0.,3*s,3*s],[s,3*s,0.,2*s],[s,3*s,2*s,0.]]},
              'expected':'negative_limb','taxa':['A'],'length':-s/2,'length_bits':bits(-s/2),
              'independent_reason':'Canonical AB/CD minimum Q; A limb is s/2+(3s-7s)/4 = -s/2 in original units.'}
    s=power(1020)*(31/8)
    overflow={'name':'fitted_path_overflow','matrix':{'taxa':list('ABCD'),'values':[[0.,2*s,3*s,4*s],[2*s,0.,4*s,4*s],[3*s,4*s,0.,2*s],[4*s,4*s,2*s,0.]]},
              'expected':'numeric_overflow','stage':'fitted_paths',
              'independent_branches':{'A':str(F.from_float(s)*F(3,4)),'B':str(F.from_float(s)*F(5,4)),'C':str(F.from_float(s)*F(3,4)),'D':str(F.from_float(s)*F(5,4)),'AB|CD':str(F.from_float(s)*F(7,4))},
              'unrepresentable_BD_path':str(F.from_float(s)*F(17,4)),
              'independent_reason':'Input max is 4s, all inferred branches are finite; fitted B-D is 17s/4 > maximum binary64.'}
    assert F.from_float(s)*F(17,4)>F.from_float(maximum)
    return [five,star,mixed,unsafe,negative,overflow,gradual]


if __name__=='__main__':
    out=Path(__file__).resolve().parent/'nj_range_cases.json'
    out.write_text(json.dumps({'oracle':'hand tree/split equations and Fraction(actual binary64), not an NJ implementation',
                               'cases':cases()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'independent_cases':len(cases()),'path':str(out)}))
