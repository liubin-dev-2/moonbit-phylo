///|
test "selection audit rotated branches and permuted inputs preserve semantic plans" {
  let tree_0 = @phylo.PhyloTree::from_newick(
    "[&R](('D':5,'C':4):6,('B':2,'A':1):3):999;",
  ).unwrap()
  check_pd_greedy(
    tree_0,
    [],
    ["D", "C", "B", "A"],
    2U,
    ["D", "B"],
    0x4030000000000000UL,
    [
      (
        "D",
        0x4026000000000000UL,
        [
          (["C", "D"], 0x4018000000000000UL.reinterpret_as_double()),
          (["D"], 0x4014000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "B",
        0x4014000000000000UL,
        [
          (["A", "B"], 0x4008000000000000UL.reinterpret_as_double()),
          (["B"], 0x4000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_1 = @phylo.PhyloTree::from_newick(
    "[&R](('D':5,'C':4):6,('B':2,'A':1):3):999;",
  ).unwrap()
  check_pd_greedy(
    tree_1,
    ["C", "A"],
    ["D", "C", "B", "A"],
    2U,
    ["D", "B"],
    0x401c000000000000UL,
    [
      (
        "D",
        0x4014000000000000UL,
        [(["D"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4000000000000000UL,
        [(["B"], 0x4000000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let tree_2 = @phylo.PhyloTree::from_newick(
    "[&R]('D':4,'C':3,('B':0,'A':0):2);",
  ).unwrap()
  check_pd_greedy(
    tree_2,
    [],
    ["D", "C", "B", "A"],
    3U,
    ["D", "C", "A"],
    0x4022000000000000UL,
    [
      (
        "D",
        0x4010000000000000UL,
        [(["D"], 0x4010000000000000UL.reinterpret_as_double())],
      ),
      (
        "C",
        0x4008000000000000UL,
        [(["C"], 0x4008000000000000UL.reinterpret_as_double())],
      ),
      (
        "A",
        0x4000000000000000UL,
        [
          (["A", "B"], 0x4000000000000000UL.reinterpret_as_double()),
          (["A"], 0x0000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_3 = @phylo.PhyloTree::from_newick(
    "[&R](('D':6,'C':5):7,('B':4,(('A':1):2):3):9):8;",
  ).unwrap()
  check_pd_greedy(
    tree_3,
    ["C", "A"],
    ["D", "C", "B", "A"],
    4U,
    ["D", "B"],
    0x4024000000000000UL,
    [
      (
        "D",
        0x4018000000000000UL,
        [(["D"], 0x4018000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4010000000000000UL,
        [(["B"], 0x4010000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let tree_4 = @phylo.PhyloTree::from_newick(
    "[&R]((('Petruca_panamensis':28.588018139999999,((('Minuca_vocator':10.472815730000001,('Minuca_rapax':6.284247143,('Minuca_pugnax':5.3998767860000001,'Minuca_minax':5.3998767860000001):0.88437035689999999):4.1885685859999997):9.5991007800000006,('Leptuca_pugilator':3.833608973,'Leptuca_panacea':3.833608973):16.238307540000001):5.1335391829999999,('Leptuca_crenulata':23.422326399999999,('Leptuca_latimanus':22.530761760000001,('Leptuca_leptodactyla':21.639197110000001,((('Leptuca_saltitanta':7.1832389819999998,'Leptuca_speciosa':7.1832389750000001):7.1832389750000001,('Leptuca_deichmanni':11.88143831,'Leptuca_cumulanta':11.88143831):2.4850396400000001):4.0654299570000001,('Leptuca_terpsichores':15.67585734,('Leptuca_stenodactylus':4.0896996029999997,'Leptuca_beebei':4.0896996029999997):11.58615773):2.756050573):3.207289201):0.89156464550000003):0.89156464550000003):1.7831292910000001):3.3825624429999999):6.7339780920000001,((('Xeruca_formosensis':21.839432290000001,('Tubuca_rosea':17.1537373,('Tubuca_rhizophorae':16.273419560000001,(((('Tubuca_polita':0.42445842379999998,'Tubuca_longidigitum':0.42445842379999998):11.74179474,'Tubuca_elegans':12.16625316):1.090577277,('Tubuca_signata':9.2827631509999993,'Tubuca_bellator':9.2827631509999993):3.9740672890000002):2.236889111,(('Tubuca_paradussumieri':4.3751328779999996,'Tubuca_capricornis':4.3751328779999996):10.16146736,(('Tubuca_flammula':6.3345300839999998,'Tubuca_coarctata':6.3345300839999998):4.4858643779999996,'Tubuca_arcuata':10.820394459999999):3.7162057719999999):0.957119316):0.77970000510000004):0.88031774929999995):4.6856949820000002):6.300871602,(('Paraleptuca_crassipes':6.195255822,'Paraleptuca_chlorophthalmus':6.195255822):20.351307179999999,('Gelasimus_tetragonon':13.884087450000001,(('Gelasimus_vomeris':0.68296760899999998,'Gelasimus_vocans':0.68296760899999998):1.617689116,'Gelasimus_hesperiae':2.3006567250000001):11.58343073):12.66247555):1.593740886):3.8445050599999999,('Austruca_sindensis':27.943767690000001,('Austruca_lactea':22.22790389,'Austruca_annulipes':22.22790389):5.7158637969999999):4.0410412610000002):3.337187277):8.4142211689999993,('Uca_princeps':16.7867192,('Uca_ornata':8.3933596109999993,'Uca_maracoani':8.3933596000000001):8.3933596000000001):26.94949819):0;",
  ).unwrap()
  check_pd_greedy(
    tree_4,
    [
      "Gelasimus_vocans", "Gelasimus_tetragonon", "Gelasimus_hesperiae", "Austruca_sindensis",
      "Austruca_lactea", "Austruca_annulipes",
    ],
    [
      "Leptuca_latimanus", "Leptuca_deichmanni", "Leptuca_cumulanta", "Leptuca_crenulata",
      "Leptuca_beebei", "Gelasimus_vomeris", "Gelasimus_vocans", "Gelasimus_tetragonon",
    ],
    3U,
    ["Leptuca_latimanus", "Leptuca_crenulata", "Leptuca_cumulanta"],
    0x4054519afb894dc7UL,
    [
      (
        "Leptuca_latimanus",
        0x4041a9372c29dd27UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator", "Petruca_panamensis",
            ],
            0x401aef97f3f47b5fUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator",
            ],
            0x400b0f7ce5eae725UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x3ffc87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
              "Leptuca_leptodactyla", "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (["Leptuca_latimanus"], 0x403687e000b12adbUL.reinterpret_as_double()),
        ],
      ),
      (
        "Leptuca_crenulata",
        0x40376c1d953c3cc7UL,
        [(["Leptuca_crenulata"], 0x40376c1d953c3cc7UL.reinterpret_as_double())],
      ),
      (
        "Leptuca_cumulanta",
        0x403687e000954008UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_leptodactyla",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x4009a8873d98df2cUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta", "Leptuca_speciosa",
            ],
            0x401043001215f989UL.reinterpret_as_double(),
          ),
          (
            ["Leptuca_cumulanta", "Leptuca_deichmanni"],
            0x4003e15c76788248UL.reinterpret_as_double(),
          ),
          (["Leptuca_cumulanta"], 0x4027c34be1d5c874UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_5 = @phylo.PhyloTree::from_newick(
    "[&R](('B':10000000000000000):1,'A':10000000000000000)'R';",
  ).unwrap()
  check_pd_greedy(tree_5, [], ["B", "A"], 1U, ["B"], 0x4341c37937e08000UL, [
    (
      "B",
      0x4341c37937e08000UL,
      [
        (["B"], 0x3ff0000000000000UL.reinterpret_as_double()),
        (["B"], 0x4341c37937e08000UL.reinterpret_as_double()),
      ],
    ),
  ])
}

///|
test "selection audit Newick save reload preserves semantic plans" {
  let saved_0 = read("((A:1,B:2):3,(C:4,D:5):6):999;").to_newick()
  let loaded_0 = @phylo.PhyloTree::from_newick(saved_0).unwrap()
  check_pd_greedy(
    loaded_0,
    [],
    ["A", "B", "C", "D"],
    2U,
    ["D", "B"],
    0x4030000000000000UL,
    [
      (
        "D",
        0x4026000000000000UL,
        [
          (["C", "D"], 0x4018000000000000UL.reinterpret_as_double()),
          (["D"], 0x4014000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "B",
        0x4014000000000000UL,
        [
          (["A", "B"], 0x4008000000000000UL.reinterpret_as_double()),
          (["B"], 0x4000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let saved_1 = read("((A:1,B:2):3,(C:4,D:5):6):999;").to_newick()
  let loaded_1 = @phylo.PhyloTree::from_newick(saved_1).unwrap()
  check_pd_greedy(
    loaded_1,
    ["A", "C"],
    ["A", "B", "C", "D"],
    2U,
    ["D", "B"],
    0x401c000000000000UL,
    [
      (
        "D",
        0x4014000000000000UL,
        [(["D"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4000000000000000UL,
        [(["B"], 0x4000000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let saved_2 = read("((A:0,B:0):2,C:3,D:4);").to_newick()
  let loaded_2 = @phylo.PhyloTree::from_newick(saved_2).unwrap()
  check_pd_greedy(
    loaded_2,
    [],
    ["A", "B", "C", "D"],
    3U,
    ["D", "C", "A"],
    0x4022000000000000UL,
    [
      (
        "D",
        0x4010000000000000UL,
        [(["D"], 0x4010000000000000UL.reinterpret_as_double())],
      ),
      (
        "C",
        0x4008000000000000UL,
        [(["C"], 0x4008000000000000UL.reinterpret_as_double())],
      ),
      (
        "A",
        0x4000000000000000UL,
        [
          (["A", "B"], 0x4000000000000000UL.reinterpret_as_double()),
          (["A"], 0x0000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let saved_3 = read("((((A:1):2):3,B:4):9,(C:5,D:6):7):8;").to_newick()
  let loaded_3 = @phylo.PhyloTree::from_newick(saved_3).unwrap()
  check_pd_greedy(
    loaded_3,
    ["A", "C"],
    ["A", "B", "C", "D"],
    4U,
    ["D", "B"],
    0x4024000000000000UL,
    [
      (
        "D",
        0x4018000000000000UL,
        [(["D"], 0x4018000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4010000000000000UL,
        [(["B"], 0x4010000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let saved_4 = read(
    "((('Uca_maracoani':8.3933596000000001,'Uca_ornata':8.3933596109999993):8.3933596000000001,'Uca_princeps':16.7867192):26.94949819,(((('Austruca_annulipes':22.22790389,'Austruca_lactea':22.22790389):5.7158637969999999,'Austruca_sindensis':27.943767690000001):4.0410412610000002,(((('Gelasimus_hesperiae':2.3006567250000001,('Gelasimus_vocans':0.68296760899999998,'Gelasimus_vomeris':0.68296760899999998):1.617689116):11.58343073,'Gelasimus_tetragonon':13.884087450000001):12.66247555,('Paraleptuca_chlorophthalmus':6.195255822,'Paraleptuca_crassipes':6.195255822):20.351307179999999):1.593740886,(((((('Tubuca_arcuata':10.820394459999999,('Tubuca_coarctata':6.3345300839999998,'Tubuca_flammula':6.3345300839999998):4.4858643779999996):3.7162057719999999,('Tubuca_capricornis':4.3751328779999996,'Tubuca_paradussumieri':4.3751328779999996):10.16146736):0.957119316,(('Tubuca_bellator':9.2827631509999993,'Tubuca_signata':9.2827631509999993):3.9740672890000002,('Tubuca_elegans':12.16625316,('Tubuca_longidigitum':0.42445842379999998,'Tubuca_polita':0.42445842379999998):11.74179474):1.090577277):2.236889111):0.77970000510000004,'Tubuca_rhizophorae':16.273419560000001):0.88031774929999995,'Tubuca_rosea':17.1537373):4.6856949820000002,'Xeruca_formosensis':21.839432290000001):6.300871602):3.8445050599999999):3.337187277,(((((((('Leptuca_beebei':4.0896996029999997,'Leptuca_stenodactylus':4.0896996029999997):11.58615773,'Leptuca_terpsichores':15.67585734):2.756050573,(('Leptuca_cumulanta':11.88143831,'Leptuca_deichmanni':11.88143831):2.4850396400000001,('Leptuca_speciosa':7.1832389750000001,'Leptuca_saltitanta':7.1832389819999998):7.1832389750000001):4.0654299570000001):3.207289201,'Leptuca_leptodactyla':21.639197110000001):0.89156464550000003,'Leptuca_latimanus':22.530761760000001):0.89156464550000003,'Leptuca_crenulata':23.422326399999999):1.7831292910000001,(('Leptuca_panacea':3.833608973,'Leptuca_pugilator':3.833608973):16.238307540000001,((('Minuca_minax':5.3998767860000001,'Minuca_pugnax':5.3998767860000001):0.88437035689999999,'Minuca_rapax':6.284247143):4.1885685859999997,'Minuca_vocator':10.472815730000001):9.5991007800000006):5.1335391829999999):3.3825624429999999,'Petruca_panamensis':28.588018139999999):6.7339780920000001):8.4142211689999993):0;",
  ).to_newick()
  let loaded_4 = @phylo.PhyloTree::from_newick(saved_4).unwrap()
  check_pd_greedy(
    loaded_4,
    [
      "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
      "Gelasimus_tetragonon", "Gelasimus_vocans",
    ],
    [
      "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
      "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
    ],
    3U,
    ["Leptuca_latimanus", "Leptuca_crenulata", "Leptuca_cumulanta"],
    0x4054519afb894dc7UL,
    [
      (
        "Leptuca_latimanus",
        0x4041a9372c29dd27UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator", "Petruca_panamensis",
            ],
            0x401aef97f3f47b5fUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator",
            ],
            0x400b0f7ce5eae725UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x3ffc87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
              "Leptuca_leptodactyla", "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (["Leptuca_latimanus"], 0x403687e000b12adbUL.reinterpret_as_double()),
        ],
      ),
      (
        "Leptuca_crenulata",
        0x40376c1d953c3cc7UL,
        [(["Leptuca_crenulata"], 0x40376c1d953c3cc7UL.reinterpret_as_double())],
      ),
      (
        "Leptuca_cumulanta",
        0x403687e000954008UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_leptodactyla",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x4009a8873d98df2cUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta", "Leptuca_speciosa",
            ],
            0x401043001215f989UL.reinterpret_as_double(),
          ),
          (
            ["Leptuca_cumulanta", "Leptuca_deichmanni"],
            0x4003e15c76788248UL.reinterpret_as_double(),
          ),
          (["Leptuca_cumulanta"], 0x4027c34be1d5c874UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let saved_5 = read("(A:10000000000000000,(B:10000000000000000):1)R;").to_newick()
  let loaded_5 = @phylo.PhyloTree::from_newick(saved_5).unwrap()
  check_pd_greedy(loaded_5, [], ["A", "B"], 1U, ["B"], 0x4341c37937e08000UL, [
    (
      "B",
      0x4341c37937e08000UL,
      [
        (["B"], 0x3ff0000000000000UL.reinterpret_as_double()),
        (["B"], 0x4341c37937e08000UL.reinterpret_as_double()),
      ],
    ),
  ])
}

///|
test "selection audit saved prefixes resume the full plan suffix" {
  let tree_0_0 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let prefix_0_0 = tree_0_0
    .faith_pd_greedy([], ["A", "B", "C", "D"], 0U)
    .unwrap()
  assert_eq(prefix_0_0.added_taxa, [])
  assert_eq(prefix_0_0.selected_taxa, [])
  let restored_0_0 = @phylo.PhyloTree::from_newick(tree_0_0.to_newick()).unwrap()
  check_pd_greedy(
    restored_0_0,
    prefix_0_0.selected_taxa,
    ["A", "B", "C", "D"],
    2U,
    ["D", "B"],
    0x4030000000000000UL,
    [
      (
        "D",
        0x4026000000000000UL,
        [
          (["C", "D"], 0x4018000000000000UL.reinterpret_as_double()),
          (["D"], 0x4014000000000000UL.reinterpret_as_double()),
        ],
      ),
      (
        "B",
        0x4014000000000000UL,
        [
          (["A", "B"], 0x4008000000000000UL.reinterpret_as_double()),
          (["B"], 0x4000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_0_1 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let prefix_0_1 = tree_0_1
    .faith_pd_greedy([], ["A", "B", "C", "D"], 1U)
    .unwrap()
  assert_eq(prefix_0_1.added_taxa, ["D"])
  assert_eq(prefix_0_1.selected_taxa, ["D"])
  let restored_0_1 = @phylo.PhyloTree::from_newick(tree_0_1.to_newick()).unwrap()
  check_pd_greedy(
    restored_0_1,
    prefix_0_1.selected_taxa,
    ["A", "B", "C", "D"],
    1U,
    ["B"],
    0x4014000000000000UL,
    [
      (
        "B",
        0x4014000000000000UL,
        [
          (["A", "B"], 0x4008000000000000UL.reinterpret_as_double()),
          (["B"], 0x4000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_0_2 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let prefix_0_2 = tree_0_2
    .faith_pd_greedy([], ["A", "B", "C", "D"], 2U)
    .unwrap()
  assert_eq(prefix_0_2.added_taxa, ["D", "B"])
  assert_eq(prefix_0_2.selected_taxa, ["B", "D"])
  let restored_0_2 = @phylo.PhyloTree::from_newick(tree_0_2.to_newick()).unwrap()
  check_pd_greedy(
    restored_0_2,
    prefix_0_2.selected_taxa,
    ["A", "B", "C", "D"],
    0U,
    [],
    0x0000000000000000UL,
    [],
  )
  let tree_1_0 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let prefix_1_0 = tree_1_0
    .faith_pd_greedy(["A", "C"], ["A", "B", "C", "D"], 0U)
    .unwrap()
  assert_eq(prefix_1_0.added_taxa, [])
  assert_eq(prefix_1_0.selected_taxa, ["A", "C"])
  let restored_1_0 = @phylo.PhyloTree::from_newick(tree_1_0.to_newick()).unwrap()
  check_pd_greedy(
    restored_1_0,
    prefix_1_0.selected_taxa,
    ["A", "B", "C", "D"],
    2U,
    ["D", "B"],
    0x401c000000000000UL,
    [
      (
        "D",
        0x4014000000000000UL,
        [(["D"], 0x4014000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4000000000000000UL,
        [(["B"], 0x4000000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let tree_1_1 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let prefix_1_1 = tree_1_1
    .faith_pd_greedy(["A", "C"], ["A", "B", "C", "D"], 1U)
    .unwrap()
  assert_eq(prefix_1_1.added_taxa, ["D"])
  assert_eq(prefix_1_1.selected_taxa, ["A", "C", "D"])
  let restored_1_1 = @phylo.PhyloTree::from_newick(tree_1_1.to_newick()).unwrap()
  check_pd_greedy(
    restored_1_1,
    prefix_1_1.selected_taxa,
    ["A", "B", "C", "D"],
    1U,
    ["B"],
    0x4000000000000000UL,
    [
      (
        "B",
        0x4000000000000000UL,
        [(["B"], 0x4000000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let tree_1_2 = read("((A:1,B:2):3,(C:4,D:5):6):999;")
  let prefix_1_2 = tree_1_2
    .faith_pd_greedy(["A", "C"], ["A", "B", "C", "D"], 2U)
    .unwrap()
  assert_eq(prefix_1_2.added_taxa, ["D", "B"])
  assert_eq(prefix_1_2.selected_taxa, ["A", "B", "C", "D"])
  let restored_1_2 = @phylo.PhyloTree::from_newick(tree_1_2.to_newick()).unwrap()
  check_pd_greedy(
    restored_1_2,
    prefix_1_2.selected_taxa,
    ["A", "B", "C", "D"],
    0U,
    [],
    0x0000000000000000UL,
    [],
  )
  let tree_2_0 = read("((A:0,B:0):2,C:3,D:4);")
  let prefix_2_0 = tree_2_0
    .faith_pd_greedy([], ["A", "B", "C", "D"], 0U)
    .unwrap()
  assert_eq(prefix_2_0.added_taxa, [])
  assert_eq(prefix_2_0.selected_taxa, [])
  let restored_2_0 = @phylo.PhyloTree::from_newick(tree_2_0.to_newick()).unwrap()
  check_pd_greedy(
    restored_2_0,
    prefix_2_0.selected_taxa,
    ["A", "B", "C", "D"],
    3U,
    ["D", "C", "A"],
    0x4022000000000000UL,
    [
      (
        "D",
        0x4010000000000000UL,
        [(["D"], 0x4010000000000000UL.reinterpret_as_double())],
      ),
      (
        "C",
        0x4008000000000000UL,
        [(["C"], 0x4008000000000000UL.reinterpret_as_double())],
      ),
      (
        "A",
        0x4000000000000000UL,
        [
          (["A", "B"], 0x4000000000000000UL.reinterpret_as_double()),
          (["A"], 0x0000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_2_1 = read("((A:0,B:0):2,C:3,D:4);")
  let prefix_2_1 = tree_2_1
    .faith_pd_greedy([], ["A", "B", "C", "D"], 1U)
    .unwrap()
  assert_eq(prefix_2_1.added_taxa, ["D"])
  assert_eq(prefix_2_1.selected_taxa, ["D"])
  let restored_2_1 = @phylo.PhyloTree::from_newick(tree_2_1.to_newick()).unwrap()
  check_pd_greedy(
    restored_2_1,
    prefix_2_1.selected_taxa,
    ["A", "B", "C", "D"],
    2U,
    ["C", "A"],
    0x4014000000000000UL,
    [
      (
        "C",
        0x4008000000000000UL,
        [(["C"], 0x4008000000000000UL.reinterpret_as_double())],
      ),
      (
        "A",
        0x4000000000000000UL,
        [
          (["A", "B"], 0x4000000000000000UL.reinterpret_as_double()),
          (["A"], 0x0000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_2_2 = read("((A:0,B:0):2,C:3,D:4);")
  let prefix_2_2 = tree_2_2
    .faith_pd_greedy([], ["A", "B", "C", "D"], 2U)
    .unwrap()
  assert_eq(prefix_2_2.added_taxa, ["D", "C"])
  assert_eq(prefix_2_2.selected_taxa, ["C", "D"])
  let restored_2_2 = @phylo.PhyloTree::from_newick(tree_2_2.to_newick()).unwrap()
  check_pd_greedy(
    restored_2_2,
    prefix_2_2.selected_taxa,
    ["A", "B", "C", "D"],
    1U,
    ["A"],
    0x4000000000000000UL,
    [
      (
        "A",
        0x4000000000000000UL,
        [
          (["A", "B"], 0x4000000000000000UL.reinterpret_as_double()),
          (["A"], 0x0000000000000000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_2_3 = read("((A:0,B:0):2,C:3,D:4);")
  let prefix_2_3 = tree_2_3
    .faith_pd_greedy([], ["A", "B", "C", "D"], 3U)
    .unwrap()
  assert_eq(prefix_2_3.added_taxa, ["D", "C", "A"])
  assert_eq(prefix_2_3.selected_taxa, ["A", "C", "D"])
  let restored_2_3 = @phylo.PhyloTree::from_newick(tree_2_3.to_newick()).unwrap()
  check_pd_greedy(
    restored_2_3,
    prefix_2_3.selected_taxa,
    ["A", "B", "C", "D"],
    0U,
    [],
    0x0000000000000000UL,
    [],
  )
  let tree_3_0 = read("((((A:1):2):3,B:4):9,(C:5,D:6):7):8;")
  let prefix_3_0 = tree_3_0
    .faith_pd_greedy(["A", "C"], ["A", "B", "C", "D"], 0U)
    .unwrap()
  assert_eq(prefix_3_0.added_taxa, [])
  assert_eq(prefix_3_0.selected_taxa, ["A", "C"])
  let restored_3_0 = @phylo.PhyloTree::from_newick(tree_3_0.to_newick()).unwrap()
  check_pd_greedy(
    restored_3_0,
    prefix_3_0.selected_taxa,
    ["A", "B", "C", "D"],
    4U,
    ["D", "B"],
    0x4024000000000000UL,
    [
      (
        "D",
        0x4018000000000000UL,
        [(["D"], 0x4018000000000000UL.reinterpret_as_double())],
      ),
      (
        "B",
        0x4010000000000000UL,
        [(["B"], 0x4010000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let tree_3_1 = read("((((A:1):2):3,B:4):9,(C:5,D:6):7):8;")
  let prefix_3_1 = tree_3_1
    .faith_pd_greedy(["A", "C"], ["A", "B", "C", "D"], 1U)
    .unwrap()
  assert_eq(prefix_3_1.added_taxa, ["D"])
  assert_eq(prefix_3_1.selected_taxa, ["A", "C", "D"])
  let restored_3_1 = @phylo.PhyloTree::from_newick(tree_3_1.to_newick()).unwrap()
  check_pd_greedy(
    restored_3_1,
    prefix_3_1.selected_taxa,
    ["A", "B", "C", "D"],
    3U,
    ["B"],
    0x4010000000000000UL,
    [
      (
        "B",
        0x4010000000000000UL,
        [(["B"], 0x4010000000000000UL.reinterpret_as_double())],
      ),
    ],
  )
  let tree_3_2 = read("((((A:1):2):3,B:4):9,(C:5,D:6):7):8;")
  let prefix_3_2 = tree_3_2
    .faith_pd_greedy(["A", "C"], ["A", "B", "C", "D"], 2U)
    .unwrap()
  assert_eq(prefix_3_2.added_taxa, ["D", "B"])
  assert_eq(prefix_3_2.selected_taxa, ["A", "B", "C", "D"])
  let restored_3_2 = @phylo.PhyloTree::from_newick(tree_3_2.to_newick()).unwrap()
  check_pd_greedy(
    restored_3_2,
    prefix_3_2.selected_taxa,
    ["A", "B", "C", "D"],
    2U,
    [],
    0x0000000000000000UL,
    [],
  )
  let tree_4_0 = read(
    "((('Uca_maracoani':8.3933596000000001,'Uca_ornata':8.3933596109999993):8.3933596000000001,'Uca_princeps':16.7867192):26.94949819,(((('Austruca_annulipes':22.22790389,'Austruca_lactea':22.22790389):5.7158637969999999,'Austruca_sindensis':27.943767690000001):4.0410412610000002,(((('Gelasimus_hesperiae':2.3006567250000001,('Gelasimus_vocans':0.68296760899999998,'Gelasimus_vomeris':0.68296760899999998):1.617689116):11.58343073,'Gelasimus_tetragonon':13.884087450000001):12.66247555,('Paraleptuca_chlorophthalmus':6.195255822,'Paraleptuca_crassipes':6.195255822):20.351307179999999):1.593740886,(((((('Tubuca_arcuata':10.820394459999999,('Tubuca_coarctata':6.3345300839999998,'Tubuca_flammula':6.3345300839999998):4.4858643779999996):3.7162057719999999,('Tubuca_capricornis':4.3751328779999996,'Tubuca_paradussumieri':4.3751328779999996):10.16146736):0.957119316,(('Tubuca_bellator':9.2827631509999993,'Tubuca_signata':9.2827631509999993):3.9740672890000002,('Tubuca_elegans':12.16625316,('Tubuca_longidigitum':0.42445842379999998,'Tubuca_polita':0.42445842379999998):11.74179474):1.090577277):2.236889111):0.77970000510000004,'Tubuca_rhizophorae':16.273419560000001):0.88031774929999995,'Tubuca_rosea':17.1537373):4.6856949820000002,'Xeruca_formosensis':21.839432290000001):6.300871602):3.8445050599999999):3.337187277,(((((((('Leptuca_beebei':4.0896996029999997,'Leptuca_stenodactylus':4.0896996029999997):11.58615773,'Leptuca_terpsichores':15.67585734):2.756050573,(('Leptuca_cumulanta':11.88143831,'Leptuca_deichmanni':11.88143831):2.4850396400000001,('Leptuca_speciosa':7.1832389750000001,'Leptuca_saltitanta':7.1832389819999998):7.1832389750000001):4.0654299570000001):3.207289201,'Leptuca_leptodactyla':21.639197110000001):0.89156464550000003,'Leptuca_latimanus':22.530761760000001):0.89156464550000003,'Leptuca_crenulata':23.422326399999999):1.7831292910000001,(('Leptuca_panacea':3.833608973,'Leptuca_pugilator':3.833608973):16.238307540000001,((('Minuca_minax':5.3998767860000001,'Minuca_pugnax':5.3998767860000001):0.88437035689999999,'Minuca_rapax':6.284247143):4.1885685859999997,'Minuca_vocator':10.472815730000001):9.5991007800000006):5.1335391829999999):3.3825624429999999,'Petruca_panamensis':28.588018139999999):6.7339780920000001):8.4142211689999993):0;",
  )
  let prefix_4_0 = tree_4_0
    .faith_pd_greedy(
      [
        "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
        "Gelasimus_tetragonon", "Gelasimus_vocans",
      ],
      [
        "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
        "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
      ],
      0U,
    )
    .unwrap()
  assert_eq(prefix_4_0.added_taxa, [])
  assert_eq(prefix_4_0.selected_taxa, [
    "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
    "Gelasimus_tetragonon", "Gelasimus_vocans",
  ])
  let restored_4_0 = @phylo.PhyloTree::from_newick(tree_4_0.to_newick()).unwrap()
  check_pd_greedy(
    restored_4_0,
    prefix_4_0.selected_taxa,
    [
      "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
      "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
    ],
    3U,
    ["Leptuca_latimanus", "Leptuca_crenulata", "Leptuca_cumulanta"],
    0x4054519afb894dc7UL,
    [
      (
        "Leptuca_latimanus",
        0x4041a9372c29dd27UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator", "Petruca_panamensis",
            ],
            0x401aef97f3f47b5fUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_panacea", "Leptuca_pugilator",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores", "Minuca_minax", "Minuca_pugnax", "Minuca_rapax",
              "Minuca_vocator",
            ],
            0x400b0f7ce5eae725UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni",
              "Leptuca_latimanus", "Leptuca_leptodactyla", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x3ffc87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
              "Leptuca_leptodactyla", "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (["Leptuca_latimanus"], 0x403687e000b12adbUL.reinterpret_as_double()),
        ],
      ),
      (
        "Leptuca_crenulata",
        0x40376c1d953c3cc7UL,
        [(["Leptuca_crenulata"], 0x40376c1d953c3cc7UL.reinterpret_as_double())],
      ),
      (
        "Leptuca_cumulanta",
        0x403687e000954008UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_leptodactyla",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x4009a8873d98df2cUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta", "Leptuca_speciosa",
            ],
            0x401043001215f989UL.reinterpret_as_double(),
          ),
          (
            ["Leptuca_cumulanta", "Leptuca_deichmanni"],
            0x4003e15c76788248UL.reinterpret_as_double(),
          ),
          (["Leptuca_cumulanta"], 0x4027c34be1d5c874UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_4_1 = read(
    "((('Uca_maracoani':8.3933596000000001,'Uca_ornata':8.3933596109999993):8.3933596000000001,'Uca_princeps':16.7867192):26.94949819,(((('Austruca_annulipes':22.22790389,'Austruca_lactea':22.22790389):5.7158637969999999,'Austruca_sindensis':27.943767690000001):4.0410412610000002,(((('Gelasimus_hesperiae':2.3006567250000001,('Gelasimus_vocans':0.68296760899999998,'Gelasimus_vomeris':0.68296760899999998):1.617689116):11.58343073,'Gelasimus_tetragonon':13.884087450000001):12.66247555,('Paraleptuca_chlorophthalmus':6.195255822,'Paraleptuca_crassipes':6.195255822):20.351307179999999):1.593740886,(((((('Tubuca_arcuata':10.820394459999999,('Tubuca_coarctata':6.3345300839999998,'Tubuca_flammula':6.3345300839999998):4.4858643779999996):3.7162057719999999,('Tubuca_capricornis':4.3751328779999996,'Tubuca_paradussumieri':4.3751328779999996):10.16146736):0.957119316,(('Tubuca_bellator':9.2827631509999993,'Tubuca_signata':9.2827631509999993):3.9740672890000002,('Tubuca_elegans':12.16625316,('Tubuca_longidigitum':0.42445842379999998,'Tubuca_polita':0.42445842379999998):11.74179474):1.090577277):2.236889111):0.77970000510000004,'Tubuca_rhizophorae':16.273419560000001):0.88031774929999995,'Tubuca_rosea':17.1537373):4.6856949820000002,'Xeruca_formosensis':21.839432290000001):6.300871602):3.8445050599999999):3.337187277,(((((((('Leptuca_beebei':4.0896996029999997,'Leptuca_stenodactylus':4.0896996029999997):11.58615773,'Leptuca_terpsichores':15.67585734):2.756050573,(('Leptuca_cumulanta':11.88143831,'Leptuca_deichmanni':11.88143831):2.4850396400000001,('Leptuca_speciosa':7.1832389750000001,'Leptuca_saltitanta':7.1832389819999998):7.1832389750000001):4.0654299570000001):3.207289201,'Leptuca_leptodactyla':21.639197110000001):0.89156464550000003,'Leptuca_latimanus':22.530761760000001):0.89156464550000003,'Leptuca_crenulata':23.422326399999999):1.7831292910000001,(('Leptuca_panacea':3.833608973,'Leptuca_pugilator':3.833608973):16.238307540000001,((('Minuca_minax':5.3998767860000001,'Minuca_pugnax':5.3998767860000001):0.88437035689999999,'Minuca_rapax':6.284247143):4.1885685859999997,'Minuca_vocator':10.472815730000001):9.5991007800000006):5.1335391829999999):3.3825624429999999,'Petruca_panamensis':28.588018139999999):6.7339780920000001):8.4142211689999993):0;",
  )
  let prefix_4_1 = tree_4_1
    .faith_pd_greedy(
      [
        "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
        "Gelasimus_tetragonon", "Gelasimus_vocans",
      ],
      [
        "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
        "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
      ],
      1U,
    )
    .unwrap()
  assert_eq(prefix_4_1.added_taxa, ["Leptuca_latimanus"])
  assert_eq(prefix_4_1.selected_taxa, [
    "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
    "Gelasimus_tetragonon", "Gelasimus_vocans", "Leptuca_latimanus",
  ])
  let restored_4_1 = @phylo.PhyloTree::from_newick(tree_4_1.to_newick()).unwrap()
  check_pd_greedy(
    restored_4_1,
    prefix_4_1.selected_taxa,
    [
      "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
      "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
    ],
    2U,
    ["Leptuca_crenulata", "Leptuca_cumulanta"],
    0x4046f9fecae8be67UL,
    [
      (
        "Leptuca_crenulata",
        0x40376c1d953c3cc7UL,
        [(["Leptuca_crenulata"], 0x40376c1d953c3cc7UL.reinterpret_as_double())],
      ),
      (
        "Leptuca_cumulanta",
        0x403687e000954008UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_leptodactyla",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x4009a8873d98df2cUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta", "Leptuca_speciosa",
            ],
            0x401043001215f989UL.reinterpret_as_double(),
          ),
          (
            ["Leptuca_cumulanta", "Leptuca_deichmanni"],
            0x4003e15c76788248UL.reinterpret_as_double(),
          ),
          (["Leptuca_cumulanta"], 0x4027c34be1d5c874UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_4_2 = read(
    "((('Uca_maracoani':8.3933596000000001,'Uca_ornata':8.3933596109999993):8.3933596000000001,'Uca_princeps':16.7867192):26.94949819,(((('Austruca_annulipes':22.22790389,'Austruca_lactea':22.22790389):5.7158637969999999,'Austruca_sindensis':27.943767690000001):4.0410412610000002,(((('Gelasimus_hesperiae':2.3006567250000001,('Gelasimus_vocans':0.68296760899999998,'Gelasimus_vomeris':0.68296760899999998):1.617689116):11.58343073,'Gelasimus_tetragonon':13.884087450000001):12.66247555,('Paraleptuca_chlorophthalmus':6.195255822,'Paraleptuca_crassipes':6.195255822):20.351307179999999):1.593740886,(((((('Tubuca_arcuata':10.820394459999999,('Tubuca_coarctata':6.3345300839999998,'Tubuca_flammula':6.3345300839999998):4.4858643779999996):3.7162057719999999,('Tubuca_capricornis':4.3751328779999996,'Tubuca_paradussumieri':4.3751328779999996):10.16146736):0.957119316,(('Tubuca_bellator':9.2827631509999993,'Tubuca_signata':9.2827631509999993):3.9740672890000002,('Tubuca_elegans':12.16625316,('Tubuca_longidigitum':0.42445842379999998,'Tubuca_polita':0.42445842379999998):11.74179474):1.090577277):2.236889111):0.77970000510000004,'Tubuca_rhizophorae':16.273419560000001):0.88031774929999995,'Tubuca_rosea':17.1537373):4.6856949820000002,'Xeruca_formosensis':21.839432290000001):6.300871602):3.8445050599999999):3.337187277,(((((((('Leptuca_beebei':4.0896996029999997,'Leptuca_stenodactylus':4.0896996029999997):11.58615773,'Leptuca_terpsichores':15.67585734):2.756050573,(('Leptuca_cumulanta':11.88143831,'Leptuca_deichmanni':11.88143831):2.4850396400000001,('Leptuca_speciosa':7.1832389750000001,'Leptuca_saltitanta':7.1832389819999998):7.1832389750000001):4.0654299570000001):3.207289201,'Leptuca_leptodactyla':21.639197110000001):0.89156464550000003,'Leptuca_latimanus':22.530761760000001):0.89156464550000003,'Leptuca_crenulata':23.422326399999999):1.7831292910000001,(('Leptuca_panacea':3.833608973,'Leptuca_pugilator':3.833608973):16.238307540000001,((('Minuca_minax':5.3998767860000001,'Minuca_pugnax':5.3998767860000001):0.88437035689999999,'Minuca_rapax':6.284247143):4.1885685859999997,'Minuca_vocator':10.472815730000001):9.5991007800000006):5.1335391829999999):3.3825624429999999,'Petruca_panamensis':28.588018139999999):6.7339780920000001):8.4142211689999993):0;",
  )
  let prefix_4_2 = tree_4_2
    .faith_pd_greedy(
      [
        "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
        "Gelasimus_tetragonon", "Gelasimus_vocans",
      ],
      [
        "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
        "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
      ],
      2U,
    )
    .unwrap()
  assert_eq(prefix_4_2.added_taxa, ["Leptuca_latimanus", "Leptuca_crenulata"])
  assert_eq(prefix_4_2.selected_taxa, [
    "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
    "Gelasimus_tetragonon", "Gelasimus_vocans", "Leptuca_crenulata", "Leptuca_latimanus",
  ])
  let restored_4_2 = @phylo.PhyloTree::from_newick(tree_4_2.to_newick()).unwrap()
  check_pd_greedy(
    restored_4_2,
    prefix_4_2.selected_taxa,
    [
      "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
      "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
    ],
    1U,
    ["Leptuca_cumulanta"],
    0x403687e000954008UL,
    [
      (
        "Leptuca_cumulanta",
        0x403687e000954008UL,
        [
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_leptodactyla",
              "Leptuca_saltitanta", "Leptuca_speciosa", "Leptuca_stenodactylus",
              "Leptuca_terpsichores",
            ],
            0x3fec87b294562799UL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_beebei", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta",
              "Leptuca_speciosa", "Leptuca_stenodactylus", "Leptuca_terpsichores",
            ],
            0x4009a8873d98df2cUL.reinterpret_as_double(),
          ),
          (
            [
              "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_saltitanta", "Leptuca_speciosa",
            ],
            0x401043001215f989UL.reinterpret_as_double(),
          ),
          (
            ["Leptuca_cumulanta", "Leptuca_deichmanni"],
            0x4003e15c76788248UL.reinterpret_as_double(),
          ),
          (["Leptuca_cumulanta"], 0x4027c34be1d5c874UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_4_3 = read(
    "((('Uca_maracoani':8.3933596000000001,'Uca_ornata':8.3933596109999993):8.3933596000000001,'Uca_princeps':16.7867192):26.94949819,(((('Austruca_annulipes':22.22790389,'Austruca_lactea':22.22790389):5.7158637969999999,'Austruca_sindensis':27.943767690000001):4.0410412610000002,(((('Gelasimus_hesperiae':2.3006567250000001,('Gelasimus_vocans':0.68296760899999998,'Gelasimus_vomeris':0.68296760899999998):1.617689116):11.58343073,'Gelasimus_tetragonon':13.884087450000001):12.66247555,('Paraleptuca_chlorophthalmus':6.195255822,'Paraleptuca_crassipes':6.195255822):20.351307179999999):1.593740886,(((((('Tubuca_arcuata':10.820394459999999,('Tubuca_coarctata':6.3345300839999998,'Tubuca_flammula':6.3345300839999998):4.4858643779999996):3.7162057719999999,('Tubuca_capricornis':4.3751328779999996,'Tubuca_paradussumieri':4.3751328779999996):10.16146736):0.957119316,(('Tubuca_bellator':9.2827631509999993,'Tubuca_signata':9.2827631509999993):3.9740672890000002,('Tubuca_elegans':12.16625316,('Tubuca_longidigitum':0.42445842379999998,'Tubuca_polita':0.42445842379999998):11.74179474):1.090577277):2.236889111):0.77970000510000004,'Tubuca_rhizophorae':16.273419560000001):0.88031774929999995,'Tubuca_rosea':17.1537373):4.6856949820000002,'Xeruca_formosensis':21.839432290000001):6.300871602):3.8445050599999999):3.337187277,(((((((('Leptuca_beebei':4.0896996029999997,'Leptuca_stenodactylus':4.0896996029999997):11.58615773,'Leptuca_terpsichores':15.67585734):2.756050573,(('Leptuca_cumulanta':11.88143831,'Leptuca_deichmanni':11.88143831):2.4850396400000001,('Leptuca_speciosa':7.1832389750000001,'Leptuca_saltitanta':7.1832389819999998):7.1832389750000001):4.0654299570000001):3.207289201,'Leptuca_leptodactyla':21.639197110000001):0.89156464550000003,'Leptuca_latimanus':22.530761760000001):0.89156464550000003,'Leptuca_crenulata':23.422326399999999):1.7831292910000001,(('Leptuca_panacea':3.833608973,'Leptuca_pugilator':3.833608973):16.238307540000001,((('Minuca_minax':5.3998767860000001,'Minuca_pugnax':5.3998767860000001):0.88437035689999999,'Minuca_rapax':6.284247143):4.1885685859999997,'Minuca_vocator':10.472815730000001):9.5991007800000006):5.1335391829999999):3.3825624429999999,'Petruca_panamensis':28.588018139999999):6.7339780920000001):8.4142211689999993):0;",
  )
  let prefix_4_3 = tree_4_3
    .faith_pd_greedy(
      [
        "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
        "Gelasimus_tetragonon", "Gelasimus_vocans",
      ],
      [
        "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
        "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
      ],
      3U,
    )
    .unwrap()
  assert_eq(prefix_4_3.added_taxa, [
    "Leptuca_latimanus", "Leptuca_crenulata", "Leptuca_cumulanta",
  ])
  assert_eq(prefix_4_3.selected_taxa, [
    "Austruca_annulipes", "Austruca_lactea", "Austruca_sindensis", "Gelasimus_hesperiae",
    "Gelasimus_tetragonon", "Gelasimus_vocans", "Leptuca_crenulata", "Leptuca_cumulanta",
    "Leptuca_latimanus",
  ])
  let restored_4_3 = @phylo.PhyloTree::from_newick(tree_4_3.to_newick()).unwrap()
  check_pd_greedy(
    restored_4_3,
    prefix_4_3.selected_taxa,
    [
      "Gelasimus_tetragonon", "Gelasimus_vocans", "Gelasimus_vomeris", "Leptuca_beebei",
      "Leptuca_crenulata", "Leptuca_cumulanta", "Leptuca_deichmanni", "Leptuca_latimanus",
    ],
    0U,
    [],
    0x0000000000000000UL,
    [],
  )
  let tree_5_0 = read("(A:10000000000000000,(B:10000000000000000):1)R;")
  let prefix_5_0 = tree_5_0.faith_pd_greedy([], ["A", "B"], 0U).unwrap()
  assert_eq(prefix_5_0.added_taxa, [])
  assert_eq(prefix_5_0.selected_taxa, [])
  let restored_5_0 = @phylo.PhyloTree::from_newick(tree_5_0.to_newick()).unwrap()
  check_pd_greedy(
    restored_5_0,
    prefix_5_0.selected_taxa,
    ["A", "B"],
    1U,
    ["B"],
    0x4341c37937e08000UL,
    [
      (
        "B",
        0x4341c37937e08000UL,
        [
          (["B"], 0x3ff0000000000000UL.reinterpret_as_double()),
          (["B"], 0x4341c37937e08000UL.reinterpret_as_double()),
        ],
      ),
    ],
  )
  let tree_5_1 = read("(A:10000000000000000,(B:10000000000000000):1)R;")
  let prefix_5_1 = tree_5_1.faith_pd_greedy([], ["A", "B"], 1U).unwrap()
  assert_eq(prefix_5_1.added_taxa, ["B"])
  assert_eq(prefix_5_1.selected_taxa, ["B"])
  let restored_5_1 = @phylo.PhyloTree::from_newick(tree_5_1.to_newick()).unwrap()
  check_pd_greedy(
    restored_5_1,
    prefix_5_1.selected_taxa,
    ["A", "B"],
    0U,
    [],
    0x0000000000000000UL,
    [],
  )
}
