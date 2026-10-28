# moonbit-phylo

源码仓库：[liubin-dev-2/moonbit-phylo](https://github.com/liubin-dev-2/moonbit-phylo)。双后端 CI 与工具链说明见 [CI.md](CI.md)，实际运行见 [Actions](https://github.com/liubin-dev-2/moonbit-phylo/actions/workflows/check.yml)。

原生 MoonBit 的 Newick 树分析库，模块 `liubin-dev/phylo`。提供可审计的 rooted/unrooted Robinson–Foulds 比较、二叉 Fitch 简约性、叶间距离、中点换根、保留叶修剪、有根 Faith PD、物种集合新增覆盖和逐步贪心选取报告。可选 `liubin-dev/phylo/nj` 包把用户距离矩阵接成明确无根的 NJ 树，继续使用既有距离、RF 和导出接口。运行时仅依赖 MoonBit core；Python 只用于独立验证。

## 运行

在本目录使用 MoonBit 工具链：

```powershell
moon check --target js --deny-warn
moon build --target js --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon run cmd/main --target js
moon run cmd/main --target wasm-gc
moon run cmd/diversity --target js
moon run cmd/diversity --target wasm-gc
moon run cmd/diversity_gain --target js
moon run cmd/diversity_gain --target wasm-gc
moon run cmd/diversity_select --target js
moon run cmd/diversity_select --target wasm-gc
moon run cmd/selection_resume --target js
moon run cmd/selection_resume --target wasm-gc
moon run cmd/selection_projection --target js
moon run cmd/selection_projection --target wasm-gc
```

本地验证工具链：moon 0.1.20260904，moonc v0.10.12+1634b282e。尚未发布到 Mooncakes；不提供虚构安装命令。`cmd/main` 是独立包的真实公共 API 消费者，打印完整 RF/Fitch/距离报告和换根/修剪结果。正式接口见 `pkg.generated.mbti`。

### 另一个本地模块如何使用源码包

本库尚未发布到 Mooncakes。收件人可把源码ZIP解压为`moonbit-phylo`目录，与自己的`recipient`模块放在同一父目录，用本地workspace解析依赖。`recipient/moon.mod`中声明与源码一致的版本：

```text
import {
  "liubin-dev/phylo@0.1.0",
}
```

在`recipient/moon.pkg`导入`"liubin-dev/phylo" @phylo`后，可直接使用下方公开API。于共同父目录执行：

```powershell
moon work init ./moonbit-phylo ./recipient
moon check --target js --deny-warn --frozen
moon build --target wasm-gc --deny-warn --frozen
moon -C recipient run . --target js --frozen
moon -C recipient run . --target wasm-gc --frozen
```

这里假设recipient根包是使用这些API的main包；不是从未发布的注册表下载包。已用第13轮封存ZIP的干净解压副本和独立模块验证：不携带产品构建目录或第三方包缓存，标准core仍来自已安装SDK。在既有42物种树上使用新测试请求，导出/读取/重算后继续调用绝对及增量PD，核对整树、逐步贡献边和数值；没有重跑历史测试全集。这是本地源码交付审计，不代表Mooncakes发布或外部CI验收。

## 两棵原始 Newick 的 RF 比较

`cmd/rf_compare` 是可配置的单请求/单 JSON 响应接收方，直接调用原 `rf_distance_rooted` / `rf_distance_unrooted`，不从距离矩阵重建树。两输入仍是现有单树 Newick 文本，模式必须明确给出：

```powershell
$env:PHYLO_RF_LEFT='[&R]((A,B),(C,D));'
$env:PHYLO_RF_RIGHT='[&R](A,(B,(C,D)));'
$env:PHYLO_RF_MODE='rooted'
moon run cmd/rf_compare --target js --frozen
$env:PHYLO_RF_MODE='unrooted'
moon run cmd/rf_compare --target wasm-gc --frozen
```

上例 rooted 报告 shared=CD、only_left=AB、only_right=BCD、distance=2；unrooted 则共享同一个 CD|AB split，distance=0。成功保留原 `RFComparisonReport` 的 `mode` / `taxa` / `shared` / `only_left` / `only_right` / `distance`，仅加 `ok:true`。模式精确为小写 `rooted` 或 `unrooted`，不从子节点数量猜根，也不把 mode 当解析器的强制 rooting 参数；rooted 必须两棵输入本就有 Rooted 语义。叶集合严格全等，不取交集、不补叶、不归一化身份；零内枝仍计作拓扑边。RF 不要求枝长齐全，但非法枝长仍由原解析器拒绝。

先检查 mode，再检查 left/right 是否提供，按 left、right 顺序解析，最后比较。缺项报 `missing_mode` / `missing_left` / `missing_right`，非法模式报 `invalid_mode`；解析错误为 `tree_error`，附 `input:left/right` 与原诊断。比较错误报 `rooted_tree_required`，或 `taxa_set_mismatch` 并附 `only_left_taxa` / `only_right_taxa`。错误是 `ok:false`，进程仍正常退出，接收脚本必须先检查 `ok`。空树文本是解析错误。文本环境传输继续受宿主限制，本入口不增加文件/stdin/argv 选择器、新格式或库 API；既有 path/NJ 文件入口保持原合同。

构建两个后端后，`python -B verification/rf_recipient.py --artifact-dir _build --moonrun moonrun --output rf-evidence` 会从保存的 Newick 文件向真实新进程发送请求，核对预先手工列出的完整 clade/split 报告、反向结果和明确错误，检查单响应及输入哈希。它验证新接收方的模式分派与原报告交接，不声称新 RF 算法。

## 原作者图的长度无关叶间 route

`tree.authored_leaf_route(from, to)` 返回 `Result[AuthoredLeafRouteReport, PhyloError]`，供树查看/标注接收程序用同一棵树的原 `NodeRecord` ID 高亮两叶间的节点和 child-edges。它不读取、不补齐枝长；合法树缺长度或边长为零时仍保留原 route。字段为 `from_taxon`、`to_taxon`、有序 `node_ids` / `edge_ids` 和 `authored_edge_count`，**没有距离字段**。端点精确匹配叶名；内部标签不是端点，未知名按 from、再 to 返回 `UnknownTaxon`。

在 `[&U](((A)U,B)X,(C,D)Y)R;` 上，A→C 节点为 A/U/X/R/Y/C，edge 的原 child 依次为 A/U/X/Y/C，即使向上走也不改用 parent ID。反向仅反转该序列；B→B 是一个原节点、空边数组。原 unary U、degree2 R/root seed 均保留，root stem 没有 parent edge。将 A 与 U 间细分加入 Q 会把这条原图 route 的边数从 5 改为 6。因此 count 只数**这一原图**的边，不能称作根/细分不变的拓扑距离、RF、归一化指标或填单位长度后的 patristic 距离。

Rooted/Unrooted/Unknown 标记、长度、注释和原图不被修改；结果数组由调用方持有，ID 仅对应同一树的 `nodes()`，不跨重读/变换持久，也不是布局坐标。原解析器仍拒绝非法 Newick/长度语法。旧 `patristic_path` / distance 继续先检查全树非根长度并保留原数值、错误顺序与 JSON；缺长度时包括 self 的原 `MissingLength` 不因这个新图查询而放宽。

`examples/authored_route_highlighter` 是**单独 MoonBit 模块**，只导入公开 `liubin-dev/phylo`：先保存原 nodes 快照，再把 route ID 应用到原 node/child-edge 高亮样式索引，示例不实现 viewer/布局或新文件传输。在共同父目录将本库放为 product、该示例放为 receiver，执行 `moon work init ./product ./receiver` 后可运行：

```powershell
$env:PHYLO_ROUTE_TREE='[&U](((A)U,B)X,(C,D)Y)R;'
$env:PHYLO_ROUTE_FROM='A'
$env:PHYLO_ROUTE_TO='C'
moon -C receiver run . --target js --frozen
moon -C receiver run . --target wasm-gc --frozen
```

`python -B verification/authored_route_recipient.py --moon moon --moonrun moonrun --output route-evidence` 会在新输出目录创建本地 product/receiver workspace，在真实双后端公共包消费者中，以**原节点快照映射手写 role 序列**核对精确 IDs、邻接、高亮、缺/零长度、marker/stem/显式细分、精确标签、错误和新报告 ownership。这是实际运行的公共包 highlighter 示例，不代表部署、用户签字、采用或性能证据；不重新生成旧科学参考。

## 可追溯叶间路径

`tree.patristic_path(from, to)` 返回 `Result[PatristicPathReport, PhyloError]`，让调用者核查已有叶间距离经过的节点和边。报告含精确叶名 `from_taxon` / `to_taxon`、有序 `node_ids`、有序 `edge_ids` 及 `distance`；节点序列包含两端，`edge_ids[i]` 是连接相邻节点的**子节点 ID**，向上走时也沿用该边的子节点 ID。自身到自身返回一个节点、空边数组和正零距离。零枝、单子节点、多分叉均保留；节点 ID 仅属于本次树，不能跨重读、旋转或修剪直接比较。

距离与错误直接复用 `patristic_distance`：全树非根边必须有有限非负长度，缺失长度即使不在所查询路径上也报错；精确匹配叶名，不把内部节点标签当叶、不做 Unicode 归一化。按实际 binary64 边值精确求和后一次舍入，只在请求路径结果溢出时报 `NumericOverflow`，排除根 stem。Rooted、Unrooted、Unknown 都沿用原距离语义，报告不推断生物学根、不修改树或原距离 API。

```powershell
$env:PHYLO_PATH_TREE='[&U]((A:1,B:2)X:4,(C:0,D:3)Y:8,Z:0)R:99;'
$env:PHYLO_PATH_FROM='B'
$env:PHYLO_PATH_TO='C'
moon run cmd/patristic_path --target js --frozen
moon run cmd/patristic_path --target wasm-gc --frozen
```

此例节点顺序为 B、X、R、Y、C，边的子节点依次为 B、X、Y、C，长度为 2、4、8、0，距离为 14；stem 99 不计。示例输出一个 JSON，含 `ok`、同一树的 `nodes`、既有 Rooting 序列化值（如 `"Unrooted"`）、`tree_newick` 和 `path`。先检查 `ok`；缺环境输入分别报 `missing_tree` / `missing_from` / `missing_to`，未知叶、缺失/非法长度、溢出及树解析错误有明确错误码与诊断。错误仍正常退出，不能只看进程退出码。此文本环境示例支持 JS/Wasm-GC，保留宿主长度限制；切回文本模式前清除 `PHYLO_PATH_TREE_FILE`。原始 Newick 文件模式见下，矩阵 JSON 的 NJ 文件模式另见后节；不提供 stdin。

`verification/patristic_path.py` 在两个后端的真实新进程中，以独立手工边图的 BFS 路径及 Fraction 精确和验证完整有序见证、反向/自身、Unicode 身份、旋转与导出重读、零枝/次正规数、`2^53+1+1`、无关巨大分支及必要错误。构建两个后端的 `cmd/patristic_path` 后，可运行 `python -B verification/patristic_path.py --artifact-dir _build --moonrun moonrun --output path-evidence`。只新增报告与方法；既有接口和报告字段保持。

### 原始 Newick 文件 → 路径报告（Node.js）

JS / Node.js CommonJS 宿主可将 `PHYLO_PATH_TREE_FILE` 设为原始 UTF-8 Newick 文件路径；进程自行只读文件并严格解码，再调用同一个解析器和路径函数。完整树文本不进入环境变量或 argv，不经 NJ 重建，保留原 rooting、注释、完整标签、节点/子边 ID 及原成功 JSON。文件读取不修改输入。Wasm-GC 仍支持原文本模式，指定文件则明确报 `unsupported_file_host`。

```powershell
# 写入无 BOM 的示例；也可直接指定已有原树文件。
[IO.File]::WriteAllText((Join-Path (Get-Location) 'study.newick'), '[&U]((A:1,B:2)X:4,(C:0,D:3)Y:8,Z:0)R:99;', [Text.UTF8Encoding]::new($false))
Remove-Item Env:PHYLO_PATH_TREE -ErrorAction SilentlyContinue
$env:PHYLO_PATH_TREE_FILE = (Resolve-Path -LiteralPath study.newick).Path
$env:PHYLO_PATH_FROM = 'B'
$env:PHYLO_PATH_TO = 'C'
moon run cmd/patristic_path --target js --frozen
Remove-Item Env:PHYLO_PATH_TREE_FILE
```

路径按字面读取，不 trim、不做 Unicode 归一化、不展开通配符；相对路径以进程 cwd 为准。file/text 两变量同时存在（包括空值）报 `input_source_conflict`；空路径报 `empty_tree_file`；读取失败报 `file_read_error` 并附 Node `code`；非法/截断 UTF-8 报 `invalid_utf8`。选择文件后错误直接返回，不降级到文本或默认树。来源选择/读取/解码先于端点检查；成功读到 String 后仍依次检查 from、to，再沿用原解析/领域错误映射。BOM 原样保留交给 **Newick**，不复制矩阵 JSON 的 BOM 剥离；既有解析器会拒绝这里测试的带 BOM 括号树。端点仍由环境变量传递，宿主内存、路径、权限和端点长度限制继续适用；读取是同步、全文件入内存。

实测的完整合成原树为 64 个长标签、66 条手工指定边、42,163 字节：PowerShell 5.1 设置长文本环境变量失败，同机 PowerShell 7.6/Python Unicode 环境块成功；默认 PowerShell 7.6 UTF-8 文本读取会替换测试中的非法字节。文件模式补充同进程原始字节交接及明确错误，不称为 String API 缺陷或所有 Windows 统一失败。`verification/path_file.py` 在真实 Node 新进程中只传路径与端点，独立核对完整边图、child 顺序、注释/rooting/stem、正反/自身路径和距离位模式，另含必要文件/编码/解析错误及旧双后端文本对照，保存输入前后哈希。构建两个后端后运行 `python -B verification/path_file.py --artifact-dir _build --moonrun moonrun --output path-file-evidence`。这不增加科学算法、格式或持久节点身份。

## 可选距离矩阵 → 无根 NJ 桥接

调用包额外导入 `"liubin-dev/phylo/nj" @nj` 即可使用；根包不导入该包，原 `moon.mod`、根 `moon.pkg` 和既有根 API 保留。`@nj.neighbor_joining(matrix)` 接受已有 `@phylo.DistanceMatrix`，`@nj.from_json(text)` 接受下述 JSON；两者返回 `Result[NJReport, NJError]`。正式接口见 `nj/pkg.generated.mbti`。

```powershell
$env:PHYLO_NJ_MATRIX='{"taxa":["A","B","C","D"],"values":[[0,3,9,10],[3,0,10,11],[9,10,0,7],[10,11,7,0]]}'
$env:PHYLO_NJ_REFERENCE='[&U]((A:1,B:2):5,C:3,D:4);'
moon run cmd/nj_matrix --target js --frozen
moon run cmd/nj_matrix --target wasm-gc --frozen
```

`PHYLO_NJ_REFERENCE` 可省略；提供时调用已有无根 RF 比较。程序输出一个 JSON：必须先检查 `ok`，成功才有 `[&U]` Newick、现有节点记录、规范排序的 `input` / `fitted` 矩阵、`residuals`、`max_abs_residual` / `rms_residual` 及可选 `comparison`。上例 split 为 AB|CD，四条末端枝长为 1/2/3/4、内枝长 5，所有拟合距离与输入相同，RF 和残差均为零。节点 ID 仅属于本次树。宿主环境变量的长度限制仍适用；较大矩阵可用下述文件模式，或直接调用 String / 类型化 API。

### Node.js 文件输入

`cmd/nj_matrix` 的 **JS / Node.js 宿主**还支持 `PHYLO_NJ_MATRIX_FILE`：变量只存路径，整个 UTF-8 JSON 文件由 Node 内置文件接口读取，再交给同一个 `@nj.from_json`。JSON 内容不经过环境变量或命令行参数，没有新矩阵格式、标签截短或维数降级。保留现有环境变量双后端示例；文件模式不支持 Wasm-GC，指定文件时明确返回 `unsupported_file_host`。

```powershell
# 先保存示例矩阵；也可以指定已有的 UTF-8 JSON 文件。
'{"taxa":["A","B","C","D"],"values":[[0,3,9,10],[3,0,10,11],[9,10,0,7],[10,11,7,0]]}' |
  Set-Content -LiteralPath matrix.json -Encoding utf8
Remove-Item Env:PHYLO_NJ_MATRIX -ErrorAction SilentlyContinue
$env:PHYLO_NJ_MATRIX_FILE = (Resolve-Path -LiteralPath matrix.json).Path
moon run cmd/nj_matrix --target js --frozen
Remove-Item Env:PHYLO_NJ_MATRIX_FILE
```

路径按字面值读取，不去空白、不展开通配符；相对路径相对于进程工作目录。文件只读，严格拒绝非法 UTF-8 为 `invalid_utf8`，保留至多一个起始 BOM 的既有 JSON 规则。路径为空报 `empty_matrix_file`，文件不存在或无法读取报 `file_read_error` 并附 Node `code`；两种矩阵来源同时存在（即使值为空）报 `input_source_conflict`。坏 JSON、字段类型及矩阵错误仍沿用原 `NJError`。与旧入口一致，错误也是一个 `ok:false` JSON，进程正常退出，消费者必须检查 `ok`。可选 `PHYLO_NJ_REFERENCE` 的原有行为和环境大小限制继续适用。

这是宿主运输能力补充：128 物种手工树的 68,194 字节 JSON 在 Windows PowerShell 5.1 设置长环境变量失败；同机 PowerShell 7.6 和 Python 直接传 Unicode 环境块成功，故不声称所有 Windows 路径均失败。文件模式通过真实 Node 新进程读取同样的完整输入，独立核对 253 条枝、125 个内 split 和 16,384 个有序路径，以及 Unicode 标签、小矩阵、非法 UTF-8、JSON 类型与文件错误；输入文件前后 SHA-256 相同。可复核运行 `python -B verification/nj_file.py --artifact-dir _build --moonrun moonrun --output file-evidence`（先构建 JS 与 Wasm-GC）。读取是同步、全文件入内存，仍受宿主内存/路径/权限和现有 2..128 / NJ 数值规则约束，不提供流式或 stdin 接口。

输入 JSON 恰有 `taxa`、`values` 两个键。物种数为 2..128；名称非空且按解码后精确字符串唯一，不去空白、不做 Unicode 归一化，`Café` 与 `Café` 是不同身份。矩阵必须方形、轴长匹配、有限、非负、对角严格为零、严格对称，容差为 **0**；正负零均接受并规范为正零。错误索引指向原输入顺序。类型化输入的 NaN/Infinity 被拒绝；非法 JSON 数字报解析或有限性错误，不修补输入。不要求三角不等式或可加性。

算法先按 MoonBit 字符串 UTF-16 字典序重排双轴，再沿发布版 NJ 的行和、Q 和距离缩减公式计算。严格比较实际 binary64 Q；完全相等时取活动数组首个 `i<j`，未合并项保持顺序、新簇追加。四叶互补 Q 平局和三簇的固有平局不代表拓扑精度证明。零枝保留，既有 RF 会把零内枝当作存在的拓扑边。

负计算枝长明确返回 `negative_limb`，附簇叶集、原输入单位的枝长及位模式；负零和除二前已为负的极小分子也不会被裁剪成成功树。先沿原 binary64 次序计算，原本成功的结果保持原路径；仅在 NJ 构建中间溢出时，从原矩阵以 `2^-8` 单位重新计算一次，导出枝长乘回 `2^8`。转换必须精确往返，非零转换输入和距离中间量须保持正规数；落入次正规数区间、除法丢成零、恢复枝长溢出或最终路径不可表示，均报 `numeric_overflow`。这项保守补强仍可能拒绝部分本可表示的树，**不承诺所有有限矩阵都能成功**，不放宽输入容差或裁枝。

例如枝长为 `2/3/5/6/7/13/8 × 2^1019` 的五叶可加树，最大路径为 `31 × 2^1019`，虽行和溢出，仍能返回其精确 binary64 枝和路径；混合案例同时保留 `2^-1000` 末端枝和 `2^1023` 距离。若缩放会损失 `2^-1073` 的正距离，仍明确报范围错误。两叶采用规范首叶 0 枝、次叶完整距离，保留最小正 binary64 的唯一路径；末三簇用三枝星形结束。输出明确无根，不选生物学祖先、不自动换根，也不自动进入 PD；直接调用既有 `faith_pd` 仍报 `RootedTreeRequired`。

残差定义为 `D' - D`，最大值为绝对残差最大值，RMS 在无序 `i<j` 对上按最大残差缩放计算。任意非可加矩阵通常 `D' != D`；例如四点环 `[[0,1,2,1],[1,0,1,2],[2,1,0,1],[1,2,1,0]]` 按声明的平局规则取 AB|CD，末端枝及内枝均为 0.5，最大残差 0.5、RMS 为 `sqrt(1/6)`。NJ 使用检查过的 binary64 算术，舍入可能损失极小正枝，残差会披露；既有核心距离/PD 的精确整数累计未改变。

复用来源为实际发布的 `IvanAXu/BioSeqs@0.1.9` ZIP。整包在本地 SDK 编译失败后，只适配其中 NJ 构建子集；保留 Apache-2.0 许可与显著修改说明，详见 [nj/UPSTREAM.md](nj/UPSTREAM.md)。已隔离运行未改 NJ 源码，复现有限大数产生 NaN/Infinity、两叶最小正数路径丢失；发布代码本身不裁剪负枝。本桥接不是 BioSeqs 全包兼容实现，也不将经典 NJ 声称为新算法。

新验收覆盖手算可加树的枝/路径/split、环形残差、负枝、零枝、2/3/128 边界、Unicode/重复身份、坏形状/有限性/对称性等。固定 Biopython 1.88、NumPy 2.5.4 的三组五叶参考包含噪声和分数枝，精确有理数检查排除参考矩阵中的拓扑歧义，再对照无根分支和拟合路径（绝对 `1e-10` 加相对 `1e-12`）；整数/最小正数手算案例使用精确期待，不借容差掩盖丢失。验证脚本只用于离线参考，不进入 MoonBit 运行依赖：

```powershell
moon test nj --target js --deny-warn --frozen
moon test nj --target wasm-gc --deny-warn --frozen
moon build cmd/nj_matrix --target js --deny-warn --frozen
moon build cmd/nj_matrix --target wasm-gc --deny-warn --frozen
# 在隔离环境按 verification/nj-reference-requirements.txt 安装参考库后：
python -B verification/nj_reference.py --artifact-dir _build --moonrun moonrun --output nj-validation
python -B verification/nj_range.py --artifact-dir _build --moonrun moonrun --output nj-range-validation
```

范围回归另以手定树及 `Fraction(实际 binary64)` 的独立预期逐位核对枝与路径，覆盖最大有限三叶星形、混合量级、缩放中间下溢、原单位负枝和真实拟合路径溢出；不会在验证时重新生成期待值。

这里不提供序列对齐、替换模型、bootstrap 或真祖先/无偏保证，也没有新增性能承诺。

## 公共 API 示例

在调用包的 moon.pkg 中导入 `"liubin-dev/phylo" @phylo`。本地示例已经完成此配置。

```moonbit nocheck
///|
let a = @phylo.PhyloTree::from_newick("[&R]((A:1,B:2):3,(C:4,D:5):6);").unwrap()

///|
let b = @phylo.PhyloTree::from_newick("[&R](A,(B,(C,D)));").unwrap()

///|
let rooted = a.rf_distance_rooted(b).unwrap() // distance = 2

///|
let unrooted = a.rf_distance_unrooted(b).unwrap() // distance = 0

///|
let traits : Map[String, Char] = { "A": '0', "B": '?', "C": '1', "D": '1' }

///|
let inferred = a.fitch_parsimony(traits).unwrap()

///|
let distances = a.patristic_matrix().unwrap()

///|
let rerooted = a.midpoint_root().unwrap()

///|
let pruned = a.prune(["A", "C"]).unwrap()

///|
let coverage = a.faith_pd(["A", "C"]).unwrap() // total_length = 14

///|
let increment = a.faith_pd_gain(["A"], ["C", "D"]).unwrap() // gain = 15

///|
let plan = a.faith_pd_greedy(["A"], ["B", "C", "D"], 2U).unwrap()
```

示例使用 unwrap 简化展示；生产调用应匹配 `Ok(value)` / `Err(PhyloError)`。所有主入口返回 Result，常见错误包括 Syntax（Char偏移）、DuplicateTaxon、RootedTreeRequired、PolytomyNotSupported、UnaryNotSupported、TaxaSetMismatch、TraitMismatch、MissingLength 与 NumericOverflow。

## Newick 与 rooting 合同

`NewickReader()` 可连续 `feed(String)`，最后 `finish()`。逐 Char 状态机跨 chunk 保持引号、嵌套注释和词元状态，不缓存完整源文本；finish 后或出错后不会继续修改返回的树。chunk 是有效 Unicode String，不是任意拆分的 UTF-8 字节。

- 单棵树，必须以分号终止；拒绝尾随第二棵树。支持内部节点标签、科学记数分支长度、单引号标签及双单引号转义。
- 未引号下划线按 Newick 传统解码为空格；引号内原样保留。解码后非空且唯一的叶标签就是 taxon ID，区分大小写。内部标签不会被猜成 bootstrap。
- 嵌套方括号注释按文本保存。节点后注释附着该节点；尚无 current node 的注释放在 tree_comments；不承诺原始空白、注释位置或字节级保真。NHX 仅保存原文，不解释类型化字段。
- 前导 `[&R]` / `[&U]` 或 `rooted=true/false` 指定模式，矛盾报错。两者都没有时为 Unknown；语法根不自动表示生物学定根。
- 显式长度必须 finite 且非负，零允许，缺失保留 None。多分叉和一元树可以解析，限制由具体算法检查。
- `to_newick()` 非递归序列化，统一给标签加引号；返回独立 `NodeRecord` 快照，修改快照数组不会修改原树。

## 算法与证据输出

| API | 行为和输出 |
|---|---|
| rf_distance_rooted | 两棵树必须 Rooted、叶集合全等；比较 `1 < clade大小 < 叶数` 的后代集合，不与补集合并。 |
| rf_distance_unrooted | 显式忽略语法根/Rooting方向，把底层树作无根比较；两侧都至少2叶，选择不含字典序最小taxon的一侧。 |
| RFComparisonReport | 排序taxa、shared、only_left、only_right完整集合及原始整数对称差；准确比较数组，不用64位哈希等价近似。超过64叶也适用；0边保留拓扑，不自动collapse。 |
| fitch_parsimony | 只接受Rooted，叶0孩子、内部2孩子，允许非平衡；单叶合法，多叉/一元明确拒绝，不暗中二叉化。等权无序的单Char性状，每叶必须有键且无多余键。 |
| ParsimonyResult | score、逐节点局部downpass candidates、一组确定性最优 assignment、changed_edges、missing_taxa。局部集合不宣称是全部全局最优祖先状态集合。 |
| patristic_distance / matrix | 每条非根边都必须有长度；root stem不计入路径。按已解析的binary64边长精确累加，完整路径只舍入一次；矩阵返回字典序taxa和对应数值，单叶矩阵为[[0]]，最终舍入为Infinity时报NumericOverflow。 |
| midpoint_root | 返回新树，不修改输入；见下方变换合同。 |
| prune(retain) | 非空、唯一、已存在的保留叶集合；压缩一元路径，长度相加，缺失传播为None，保留叶间距离。 |
| faith_pd(present) | Rooted且非根长度完整；选中叶到研究根的分支并集，每条边只计一次，返回FaithPDReport及原边NodeId证据。 |
| faith_pd_gain(baseline, additions) | 在基线物种集合之外新增覆盖的分支长度，返回FaithPDGainReport及新增贡献边；直接累加新边，避免相减舍入后的绝对PD。 |
| faith_pd_greedy(baseline, candidates, limit) | 在候选池内逐步选取limit个新增物种，每步重算精确增量、真平局按字典序，返回选择顺序和逐步原边证据。 |
| faith_pd_plan_document(baseline, candidates, limit) | 校验并导出自带研究树、请求和结果声明的FaithPDPlanDocument，可用to_json保存。 |
| FaithPDPlanDocument::from_json / replay | 前者读取版本化JSON字段，后者重算并逐项核对声明，成功返回重建树及该树的计划报告。 |

Fitch 的 `?` 是没有观测约束：取本次实际观测的状态字母表，不删叶、不改变树。全部 `?` 时 score=0，assignment为None，不虚构祖先状态。`-` 暂拒绝；其余Char均为字面状态，不自动展开IUPAC编码。明确不支持权重、比对矩阵与Sankoff。

### Faith PD：比较物种集合覆盖的演化分支

`faith_pd(present)`接收已观测叶的taxon ID集合，计算这些叶到研究根的全部分支并集长度。共同分支只计一次，选中叶共同祖先之上的根路径也计入，root stem不计入。因此它不是修剪后最小连接子树的总长。定义参见[scikit-bio Faith PD](https://scikit.bio/docs/latest/generated/skbio.diversity.alpha.faith_pd.html)。

`FaithPDReport`包含字典序`selected_taxa`、输入树的`root_id`、升序`edge_ids`及`total_length`。每个edge ID是输入树中该边的子节点，可用`nodes()[id].parent/length`逐边审计；零长贡献边也列出。返回新报告，输入树和传入数组不变。完整分支并集精确累加已解析Double，再按最近偶数舍入一次；最终Infinity返回NumericOverflow。

必须明确Rooted；Unknown/Unrooted返回RootedTreeRequired。一元树和多叉树可用；所有非根边都要求长度完整，未选中边及空集合也执行这一严格长度校验。有效树上的空集合PD为0；未知叶和重复选择分别报UnknownTaxon、DuplicateSelection，不会静默忽略。单叶树若叶就是根则没有贡献边。这里仅做物种存在/缺失集合的有根Faith PD，不提供丰度加权、无根PD、最优物种选择或自动生态决策。

`cmd/diversity`演示同样选择两种物种时，`[A,B]`的PD为6，`[A,C]`为14；单独A为4，空集合为0。输出是完整JSON报告，可核对为何共享祖先不同会得到不同覆盖量。53组独立预期覆盖三种四叶拓扑的全部子集及既有42-taxon研究树上的五组测试物种集合，后者不代表论文的真实群落观测。

### 增量 Faith PD：已有集合之外增加了什么

`faith_pd_gain(baseline, additions)`计算加入一组物种后新增覆盖的演化分支。对每条原边，只有新增集合覆盖它且基线没有覆盖它时才计入；共同新祖先只计一次。精确算术下，它等于并集PD减去基线PD。实现直接累加新边，最后舍入一次，因此`(A:10000000000000000,B:1)`上给A加入B仍返回gain=1，即使两个绝对PD都正确舍入成10000000000000000。

`FaithPDGainReport`给出排序的`baseline_taxa`、真正新加入的`added_taxa`、输入树`root_id`、升序新增`edge_ids`和`gain`。两数组各自不能重复或包含未知叶；跨数组重叠合法，已有物种不会再计入added_taxa。空集合合法，零长新边仍列入证据，root stem排除；输入树和数组保持不变。Rooted及全树非根边完整长度要求与faith_pd一致。

只判断新增边总和是否最终舍入为Infinity；即使基线或并集的绝对PD溢出，有限gain仍可报告。返回值和边长仍为Double，不承诺任意精度公开结果。该查询仅度量给定组合的增量，不执行预算优化、自动推荐或丰度加权。

`cmd/diversity_gain`以A为基线，依次加入B/C/D/C+D/A，返回gain为2/10/11/15/0。C和D分别加入时各含一条新祖先边，共同加入时这条边只计一次；示例另输出上面的gain=1。271组独立分支集合/Fraction预期包含256对小树子集、10组一元/多叉场景和5组既有42-taxon树场景，原有数据与参考生成器没有重跑。

### 逐步贪心选取：把物种选择接到覆盖与分支复核

`faith_pd_greedy(baseline, candidates, limit: UInt)`每步选择精确新增分支总长最大的候选，然后更新已覆盖的分支再算下一步。精确值真正相同时才按taxon字典序选择；公开Double增量相同不代表真平局。它选择`min(limit, 合法候选数)`个，即使最后几步gain为0也会保留选择；UInt使上限非负，0允许。候选池中已有的基线物种排除，两数组内部重复或未知标签仍报错，跨数组重叠合法。根模式与全树完整长度要求沿用Faith PD。

`FaithPDGreedyReport`包含排序的`baseline_taxa`、排除基线后的`candidate_taxa`、原`limit`、按选择顺序排列的`added_taxa`、排序的最终`selected_taxa`、输入树`root_id`、新增边并集`edge_ids`和`gain`。每个`FaithPDGreedyStep`给出taxon、本步升序原边ID及gain。各步新边互不重叠；总gain从完整新边并集精确累加后舍入一次，不是把各步已舍入的gain再相加。输入树和数组不变，root stem排除。

只要求返回的逐步及总增量有限；绝对基线PD溢出不影响有限增量。limit=0仍校验根、标签和所有非根边长度，但不因未选择候选的路径总长而报溢出。步骤或总增量最终舍入为Infinity时返回NumericOverflow。

`cmd/diversity_select`走完选择→绝对PD/新增覆盖→原贡献边复核流程。在B边长为8的示例中，以A为基线选两个候选：固定初始排名会选D+C，gain为15；逐步重算选择D+B，gain为19，最终PD为23。另一个例子公开增量都为1e16，精确比较仍选出多一段长度1的B。此接口提供明确的贪心流程，不含成本、物种依赖或灭绝概率约束；不套用其它PD约定下的定理作一般约束最优性承诺。

106组独立Fraction/分支事实用例枚举875个候选顺序，检查每步选择及完整分支多重集；在各自有限候选池中另枚举最终子集核对覆盖最大值。包含四组既有42-taxon树场景，未重跑旧生成器或下载新数据。

已有接口也可分阶段选取：保存树的`to_newick()`结果和首段计划的`selected_taxa`，重读这棵树后，用该物种集作基线、原候选池及剩余数量上限继续调用`faith_pd_greedy`。`cmd/selection_resume`在既有42物种树上的测试集合演示先选1个、保存/重读后续选2个，打印首段、续段、完整计划、最终绝对PD/原基线增量和两棵树的节点记录。NodeId仍只属于各自输入树，贡献边须对应各自节点记录；跨阶段转交的是物种身份。最终总增量通过原基线和合并的新增物种重新查询，避免相加已舍入的阶段数值。

本流程另有6组子分支旋转/输入排列、6组保存重读和19个续算断点审查，核对语义分支事实而非强求跨树NodeId相同。研究树上的物种集合仍是测试构造，不是论文观测群落；这不增加新的库接口或树格式。

若用`prune`生成审阅投影，先在原始研究根树上完成精度敏感的计划，再用`TransformWitness`把投影边回溯到原树路径。一元路径合并成一个Double时，不能保证保留原路径的全部精确位。例如`(A:10000000000000000,(B:10000000000000000):1)R;`上，原树精确贡献较大的B先被选中；全叶修剪压缩B路径后，新B边舍入为1e16，与A真正相等，新树按字典序选A。这符合既有Double变换边界，不能把压缩视图当成原始路径的无损替代。

`cmd/selection_projection`保留全部叶，以隔离节点重编与一元压缩影响：输出投影witness、投影/重读计划及各自节点记录，并展示上述数值边界。投影边先按投影节点定位，再沿witness核对原树边；投影保存重读后，应改用重读树的节点记录，原witness编号不会自动跨树更新。另有四组独立压缩/原边展开、四组投影保存重读和一个精度边界用例，包含实际被选中的压缩一元路径。

### 保存、分享与重新复核计划

`faith_pd_plan_document`把已有贪心选择包装成一个自带输入的文档：研究树的Newick、基线物种、原候选池、数量上限、预期新增物种顺序、总gain和逐步gain。候选池保留与基线的合法重叠；导出时复制并排序请求数组，不依赖调用方后续保存数组。它沿用原选择器的校验与错误，不增加树格式或选择算法。

JSON的`schema`固定为`phylo/faith-pd-greedy-plan/v1`。另外七个字段为`tree_newick`、`baseline_taxa`、`candidate_taxa`、`limit`、`expected_added_taxa`、`expected_gain`、`expected_step_gains`。`limit`使用十进制**字符串**（如`"2"`），精确支持UInt的0到4294967295，避免JSON数字转换造成截断；旧计划报告中的limit仍是数字。gain字段是有限非负JSON数字，物种数组只包含字符串；未知字段、缺失字段、错误类型和未知schema均拒绝。

`FaithPDPlanDocument::from_json(text)`只确认语法、版本和字段合法，接受可选的开头UTF-8 BOM。随后必须调用`replay()`，重建内嵌研究树并执行原选择器，核对新增物种顺序、总gain及每步gain。`PlanDocumentError`区分InvalidJson、InvalidField、UnsupportedSchema、TreeError和ClaimMismatch；原PhyloError保持不变。成功返回`(tree, plan)`，贡献边ID对应这个返回的tree。此处验证的是重算一致性；文件没有来源签名，不能据此证明作者身份或生态学决策有效性。

```moonbit nocheck
///|
let saved = a.faith_pd_plan_document(["A"], ["B", "C", "D"], 2U).unwrap()

///|
let text = saved.to_json().stringify()

///|
let loaded = @phylo.FaithPDPlanDocument::from_json(text).unwrap()

///|
let (review_tree, review_plan) = loaded.replay().unwrap()
```

`cmd/plan_document`导出一个gain=19、顺序D/B的演示文档，每次只输出一个JSON对象。review模式从当前子进程的`PHYLO_PLAN_DOCUMENT`读取外部文本；库本身接收String，文件读写由宿主完成。在PowerShell中可保存文件并交给另一个后端复核：

```powershell
moon run cmd/plan_document --target js -- export | Set-Content -LiteralPath plan.json -Encoding utf8
$env:PHYLO_PLAN_DOCUMENT = Get-Content -LiteralPath plan.json -Raw -Encoding utf8
moon run cmd/plan_document --target wasm-gc -- review
Remove-Item Env:PHYLO_PLAN_DOCUMENT
```

成功输出`schema=phylo/faith-pd-greedy-review/v1`、`ok=true`、document、plan和nodes；失败输出`ok=false`和错误分类。示例通过JSON的ok判断成功，领域错误仍正常退出。环境变量传输受宿主进程大小限制；应用可自行读文件后直接调用纯库接口。双后端验证包括真实42物种树的测试集合、Unicode/BOM、0/UInt最大上限、跨进程保存重读，以及错误版本、非法字段和被修改声明；测试集合仍非论文观测数据。

#### 从自己的树文件创建计划

`create`模式读取`PHYLO_PLAN_REQUEST`，补齐“用户树/请求 → 可分享计划 → 复核”的命令链。请求schema为`phylo/faith-pd-greedy-request/v1`，恰有五个必需字段：schema、tree_newick字符串、baseline_taxa字符串数组、candidate_taxa字符串数组、limit十进制字符串。接受可选的开头BOM；未知/缺失字段、错误类型、未知版本、超出UInt范围均返回结构化错误。0、4294967295、空集合及基线/候选合法重叠继续支持。

以下以自己的`study.newick`创建请求文件；数组内名称必须是该树实际存在的taxon。Newick必须显式标Rooted（例如开头`[&R]`），命令不猜测根模式。

```powershell
$phyloRequest = @{
  schema = 'phylo/faith-pd-greedy-request/v1'
  tree_newick = (Get-Content -LiteralPath study.newick -Raw -Encoding utf8)
  baseline_taxa = @('Xeruca_formosensis', 'Uca_princeps', 'Petruca_panamensis')
  candidate_taxa = @('Minuca_minax', 'Leptuca_beebei', 'Gelasimus_tetragonon', 'Tubuca_rosea', 'Paraleptuca_crassipes')
  limit = '2'
}
$phyloRequest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath request.json -Encoding utf8
$env:PHYLO_PLAN_REQUEST = Get-Content -LiteralPath request.json -Raw -Encoding utf8
moon run cmd/plan_document --target js -- create | Set-Content -LiteralPath study-plan.json -Encoding utf8
$env:PHYLO_PLAN_DOCUMENT = Get-Content -LiteralPath study-plan.json -Raw -Encoding utf8
moon run cmd/plan_document --target wasm-gc -- review
Remove-Item Env:PHYLO_PLAN_REQUEST
Remove-Item Env:PHYLO_PLAN_DOCUMENT
```

成功create只输出现有`phylo/faith-pd-greedy-plan/v1`文档，原review可直接读取。失败输出`ok=false`和invalid_json、invalid_field、unsupported_schema、tree_error或missing_request；与原review一样，调用者须检查JSON状态，失败对象不是计划。树/标签/长度/溢出校验全部交给原库，缺失长度、重复/未知taxon等不被静默忽略。此CLI仍采用宿主文件读写及进程环境变量传输；较大输入的应用可直接调用库API。

这一步只增加命令入口，不新增库API或算法。独立验证以新请求字节驱动双后端create，再保存输出并跨后端review，核对既有42物种树上的新测试请求及完整分支事实；旧演示export/default、review与已保存计划格式保留。

#### 按字段定位计划入口错误

CLI失败仍通过`ok=false`和既有`error`分类返回，进程正常退出。`invalid_field`与`claim_mismatch`现在附加`field`，原样保留库错误携带的标识，例如`limit`、`expected_gain`或`chain`等根对象标识；它不是JSON Pointer或完整嵌套路径。原`detail`继续用于显示，消费者无需解析其中的repr文本。`stage_failed`的字段在`cause.field`，阶段仍由从0开始的`stage_index`定位；`chain_mismatch`原有的顶层`field`保持不变。

没有字段标识的错误不臆测位置：`tree_error`、`invalid_json`、`unsupported_schema`及自定义缺失输入错误沿用既有形状。消费者应允许新增的可选成员，并在无`field`时显示一般错误；成功文档/复核schema、输入校验和库API均未改变。例如读取某次失败报告：

```powershell
$phyloError = Get-Content -LiteralPath review-error.json -Raw -Encoding utf8 | ConvertFrom-Json
if ($phyloError.ok -ne $false) { throw 'Expected an error report' }
$phyloDiagnostic = if ($phyloError.error -eq 'stage_failed') { $phyloError.cause } else { $phyloError }
if ($phyloDiagnostic.PSObject.Properties.Name -contains 'field') {
  [pscustomobject]@{ stage_index = $phyloError.stage_index; field = $phyloDiagnostic.field; error = $phyloDiagnostic.error }
} else {
  [pscustomobject]@{ error = $phyloDiagnostic.error; detail = $phyloDiagnostic.detail }
}
```

#### 从已保存计划续选

`resume`读取`PHYLO_PLAN_DOCUMENT`中的旧计划和`PHYLO_PLAN_ADDITIONAL_LIMIT`中的额外数量（十进制字符串，0到4294967295）。它先from_json再replay核对全部旧声明，即使额外数量为0也执行复核；随后以重算报告的selected_taxa作新基线，沿用旧文档的研究树及原候选请求，调用原选择器继续。无需手工复制物种集，也不引入新优化算法。

```powershell
$env:PHYLO_PLAN_DOCUMENT = Get-Content -LiteralPath study-plan.json -Raw -Encoding utf8
$env:PHYLO_PLAN_ADDITIONAL_LIMIT = '2'
moon run cmd/plan_document --target js -- resume | Set-Content -LiteralPath continuation.json -Encoding utf8
$env:PHYLO_PLAN_DOCUMENT = Get-Content -LiteralPath continuation.json -Raw -Encoding utf8
moon run cmd/plan_document --target wasm-gc -- review
Remove-Item Env:PHYLO_PLAN_DOCUMENT
Remove-Item Env:PHYLO_PLAN_ADDITIONAL_LIMIT
```

成功仍只输出`phylo/faith-pd-greedy-plan/v1`。新文档的baseline是旧计划已选集合，limit和expected_gain均只描述**续选阶段**；候选耗尽时返回空新增，零增量候选仍按原规则选取。保留旧文件作为历史；若要从最初基线计算总增量，应在原树上用合并的新增物种重新查询faith_pd_gain，不能把已舍入的阶段gain直接相加。贡献边ID仍属于各自复核返回的树，文档不存跨树ID或父计划字段。

旧声明不符会报claim_mismatch，语法/字段/树错误沿用既有分类，缺少环境输入分别报missing_document或missing_additional_limit。原create、export/default和review保持原行为；错误仍用ok=false表示，进程正常退出，宿主须检查输出。文件读写和环境传输大小限制继续适用。

#### 多轮链复核与累计增量

`review-chain`从`PHYLO_PLAN_CHAIN`读取按顺序排列的非空JSON数组，每个元素仍是原`phylo/faith-pd-greedy-plan/v1`计划。它逐份from_json并replay，包括零新增阶段；再检查每段基线等于上一段重算后的selected_taxa、候选请求集合保持不变，以及研究树经现有to_newick归一后的字符串与首段相同。候选/基线数组排列、树的空白及等值数字写法可归一；这不是任意树表示之间的等价判定。

```powershell
$phyloChain = @(
  (Get-Content -LiteralPath study-plan.json -Raw -Encoding utf8 | ConvertFrom-Json)
  (Get-Content -LiteralPath continuation.json -Raw -Encoding utf8 | ConvertFrom-Json)
  (Get-Content -LiteralPath continuation-2.json -Raw -Encoding utf8 | ConvertFrom-Json)
)
ConvertTo-Json -InputObject $phyloChain -Depth 8 | Set-Content -LiteralPath chain.json -Encoding utf8
$env:PHYLO_PLAN_CHAIN = Get-Content -LiteralPath chain.json -Raw -Encoding utf8
moon run cmd/plan_document --target wasm-gc -- review-chain
Remove-Item Env:PHYLO_PLAN_CHAIN
```

成功报告schema为`phylo/faith-pd-greedy-chain-review/v1`，包含原基线、各段顺序/增量、最终已选集、验证过的documents及首树nodes。`cumulative`从首树上用原基线和最终物种集调用faith_pd_gain重新计算，**不累加stage_gains**。其贡献边ID只对应报告的首树nodes，保持整数；报告不混用各段边ID。报告是摘要，后续resume仍读取某份原计划。

顶层`ok=true`表示各段和衔接有效；`cumulative.ok=true`时report给出可表示的累计增量。若各段增量有限、累计值却溢出，顶层仍为true，`cumulative.ok=false`并给出NumericOverflow，不能把一条有效链说成无效，也不输出Infinity。段解析/重算失败则顶层`ok=false,error=stage_failed`，含从0开始的整数stage_index与原cause；衔接失败为chain_mismatch及字段名。缺少输入为missing_chain，空数组/外层类型错误为invalid_field(chain)。进程退出及宿主传输限制沿用原约定。

新入口不改旧计划schema、单份review、create/resume、库API或选择算法。它验证的是这些文件之间的连续性与可重算结果，不证明作者身份，也不替用户对替代方案排名。

链复核保留研究根的具体含义：`[&R]Solo:999;`中Solo本身是根，没有非根贡献边，选中它的增量为0；`[&R](Solo:999)Study:123;`有一条999长的祖先路径，根stem123仍排除。新增的零长分支也会列入贡献边，因此“gain=0”“没有新增物种”和“没有新增边”不能互相替代。这些是既有合同的退化图审查结果，未增加算法或API。

Taxon ID按现有Newick/JSON规则解码后的精确字符串区分。例如以转义记号表示的`Caf\u00E9`和`Cafe\u0301`可以视觉相同，仍是两个不同ID；不会自动NFC合并。对计划对象使用PowerShell `ConvertTo-Json -EscapeHandling EscapeNonAscii`可以改变JSON字节表示而保留解码后的名称；另行规范化名称则是内容修改，可能制造重复或改变已选物种声明。独立分享链审查已验证两种JSON表示的双后端一致性，未新增规范化策略或API。

处理刚生成的链复核报告时，顶层ok决定链是否通过，cumulative.ok单独决定能否显示累计数值。累计不可表示时，仍可取出documents末段的原v1计划交给resume；续段会重新复核该计划并独立校验新增量。例如从自己的`review-chain`输出继续：

```powershell
$phyloReview = Get-Content -LiteralPath chain-review.json -Raw -Encoding utf8 | ConvertFrom-Json
if ($phyloReview.ok -ne $true) { throw 'The plan chain is not valid' }
$phyloCheckpoint = $phyloReview.documents[-1]
ConvertTo-Json -InputObject $phyloCheckpoint -Depth 8 | Set-Content -LiteralPath last-plan.json -Encoding utf8
$env:PHYLO_PLAN_DOCUMENT = Get-Content -LiteralPath last-plan.json -Raw -Encoding utf8
$env:PHYLO_PLAN_ADDITIONAL_LIMIT = '1'
moon run cmd/plan_document --target wasm-gc -- resume | Set-Content -LiteralPath next-plan.json -Encoding utf8
Remove-Item Env:PHYLO_PLAN_DOCUMENT
Remove-Item Env:PHYLO_PLAN_ADDITIONAL_LIMIT
```

独立消费者审查已覆盖“累计NumericOverflow、随后新增量仍为3”的边界，并重新复核追加后的整链；没有用该阶段值冒充累计值，也没有把累计不可用当作链无效。原研究树、候选池、schema及API保持不变。

#### 候选池变化时另建方案

`resume`始终沿用原候选请求，不会把树中其他叶自动加入候选池。若可选物种发生变化，先用单份`review`复核旧计划，再把报告的`plan.selected_taxa`作为新基线、`document.tree_newick`作为研究树，另发`create`请求并保存新文件。例如下面的自拟树先选Pine；原池续选会选Maple，新池则允许选择Birch：

```powershell
$phyloRequest = @{
  schema = 'phylo/faith-pd-greedy-request/v1'
  tree_newick = '[&R]((Oak:2,Maple:6):4,(Pine:7,Fir:3):5,Birch:8)Study:500;'
  baseline_taxa = @('Oak')
  candidate_taxa = @('Maple', 'Pine')
  limit = '1'
}
$env:PHYLO_PLAN_REQUEST = ConvertTo-Json -InputObject $phyloRequest -Depth 4
moon run cmd/plan_document --target js -- create | Set-Content -LiteralPath prefix-plan.json -Encoding utf8
$env:PHYLO_PLAN_DOCUMENT = Get-Content -LiteralPath prefix-plan.json -Raw -Encoding utf8
moon run cmd/plan_document --target wasm-gc -- review | Set-Content -LiteralPath prefix-review.json -Encoding utf8
$phyloReview = Get-Content -LiteralPath prefix-review.json -Raw -Encoding utf8 | ConvertFrom-Json
if ($phyloReview.ok -ne $true) { throw 'The prefix plan is not valid' }
$phyloForkRequest = @{
  schema = 'phylo/faith-pd-greedy-request/v1'
  tree_newick = $phyloReview.document.tree_newick
  baseline_taxa = @($phyloReview.plan.selected_taxa)
  candidate_taxa = @('Maple', 'Pine', 'Birch')
  limit = '1'
}
ConvertTo-Json -InputObject $phyloForkRequest -Depth 4 | Set-Content -LiteralPath fork-request.json -Encoding utf8
$env:PHYLO_PLAN_REQUEST = Get-Content -LiteralPath fork-request.json -Raw -Encoding utf8
moon run cmd/plan_document --target js -- create | Set-Content -LiteralPath fork-plan.json -Encoding utf8
Remove-Item Env:PHYLO_PLAN_REQUEST
Remove-Item Env:PHYLO_PLAN_DOCUMENT
```

本例旧链以Oak为原基线，Pine12之后续选Maple6，累计18；新方案以Oak/Pine为基线，Birch增益8。新方案可单独`review`或作为单元素数组`review-chain`，但不能追加到旧链：会在stage_index=1报`chain_mismatch`，字段为`candidate_taxa`。两个累计值的起始基线不同，不能直接据此排名。原计划文件及其候选池保持独立，不新增schema、候选池迁移命令或算法。

### 树变换 witness

`TransformResult` 包含新树及 `TransformWitness`。NodeId只在单棵树内有效：old_to_new逐旧ID给出新ID，删除或压缩节点为None，taxon叶映射完整。retained_taxa是新叶集。

edge_paths按新节点ID给出该节点对应的原树路径顶点，父节点端点可由映射反查；新根由切边插入时，用值“旧节点数”作新增顶点标记。split_edge和offset记录有向直径路径上的原切边a→b及从a量起的偏移；原边长度不变，分为offset和length-offset。这些路径可独立逐边核长度，不只看Newick字符串。根条目记录压缩历史，不是树内入边。

中点换根要求完整长度。按字典序叶对选第一条最长路径并返回diameter_endpoints/diameter；中点在顶点上就复用顶点，可能形成多叉根，绝不为Fitch强行补枝。全零直径保持原拓扑并标Rooted；并列最长路径按固定叶顺序解决。旧一元根的非taxon悬枝会删除，变换后的stem不混入叶间距离。被压缩节点的标签/注释不强行移到别的节点，原树及None映射仍可审计。

## 复杂度与本期边界

库的解析、序列化、遍历和变换不递归访问树。已用万叶、深度9999梳形树验证读写，未据此声称全部算法均适合万叶全矩阵。

矩阵/直径扫描访问 O(L*N) 个路径节点（L叶数、N节点数），矩阵输出O(L²)空间。长度累加使用core/bigint的精确整数单位，整数宽度至多约2098+log₂N位，算术成本随位数增加，不视为免费常数操作。RF用完整后代标签数组和准确集合比较，保守实现的最坏时间可达O(N²*L)，空间O(N*L)，不是线性哈希RF；Fitch使用显式Char集合，状态数影响时间。Arena和工作数组有正常分配，不承诺“无分配”或已量测GC改善。

Faith PD用集合标记合并根路径，已标记的祖先不重复访问；忽略哈希和大整数的位成本时，N节点、K选中叶的预期时间O(N+K log K)，工作空间O(N+K)，证据输出最多N-1条边。不递归遍历，不引入新的运行时依赖。

增量查询为两个输入集合各标记一次根路径，再取新增边；K为两数组合计长度时，同样是预期O(N+K log K)时间和O(N+K)工作空间，另计大整数位成本。尚未作吞吐量或批处理性能声明。

贪心实现直接扫描候选根路径。设C为可选候选数、K=min(limit,C)、B为基线大小，保守时间O(K*C*N+N log N+(B+C)log(B+C))，另计哈希/大整数成本；工作数组O(N+B+C)，证据输出O(N+K)。它不是文献中经过专门优化的近线性实现，未作大树选取吞吐量声明。

NEXUS读取、类型化NHX、PhyloXML、Sankoff/权重、序列建树均明确后续；当前不是原多格式蓝图全部完成。外部数据转为Newick的Python脚本只是验证适配器。

## 验证与许可

26组外部真值场景由 Biopython 1.88、DendroPy 5.0.8生成，另有格式/错误/深树/witness测试。小树Fitch额外穷举内部赋值；真实研究树包含42个taxon，性状是测试专用合成观测。双后端实际结果见执行回执，不把测试个数叫生态唯一性或赛事验收。

可离线重放独立参考生成器，见 `verification/README.md`。`testdata/golden.json`含逐场景参考结果，`oracle_test.mbt`通过公共API断言；参考不是复制MoonBit算法作oracle。

源码 Apache-2.0（LICENSE）；研究树数据 CC0（testdata/LICENSE-CC0），数据不改标Apache。来源、固定身份、数据转换及许可分离见 SOURCES.md。源码已发布于本仓库；尚未发布Mooncakes，也不代表组委会验收。

## deep-repair-05 correctness fixes

不透明树注释统一序列化到终止分号之后；读取端将分号后注释识别为树级原文。因此内部出现的 `[&R]` / `[&U]` 不会在读写往返后冒充前导 rooting 指令，Unknown 保持 Unknown；前导明确指令仍照常生效。

单对 patristic_distance 只累加该叶对到共同祖先的路径；矩阵/中点计算只在要求输出的叶间路径溢出时返回 NumericOverflow。与叶间路径无关的根侧悬枝数值不污染结果，缺失长度的现有严格校验仍保留。

修剪先确定保留叶的共同根，再压缩保留的路径；最终丢弃的祖先 stem 不参与加法。若真正保留的新边溢出，仍返回 NumericOverflow。旧祖先的 None 映射及根条目的路径历史继续保留。

对于最小正 binary64 直径，除2可能舍入成0，无法表示精确的等长两半。此时换根显式插入零长边，保持端点叶身份、全部叶间长度及映射；witness如实给出可表示的 offset，不虚构更高精度。

本轮新增7项定向回归/有界审查，覆盖4个实测缺陷、两种4叶二叉形状的全部0/1/?观测（穷举赋值独立校验）、quartet完整RF报告及零/次正规/普通/巨大长度组合。既有外部真值与真实数据来源保留，未重新下载或生成旧参考全集。

## deep-repair-06 correctness fixes

压缩保留路径时，只有整条路径的长度都已知，才报告其数值和是否溢出。缺失片段无论位于路径哪一端，都传播为None；不会先因其它片段溢出而拒绝这棵合法的不完整长度树。完整保留边真正溢出时仍返回NumericOverflow，临时非有限中间值不会暴露到返回树。

非负长度校验同时检查原十进制尾数的符号：`-1e-400`即使舍入为`-0.0`也拒绝；精确零（如`-0e-400`）仍接受，正数的既有binary64下溢舍入政策不变。增量读取在指数跨chunk时采用相同规则。

本轮新增回归包含上述公开API反例及缺失/零/普通/巨大三段压缩路径的全部组合，期望由缺失值传播规则、独立图路径witness检查和Python Decimal的精确符号分类确立。没有重新下载研究树或重生成既有参考全集。

## deep-repair-07 numerical fixes

距离与压缩路径的内部累加以2^-1074为整数单位，保留输入Double的精确值，完整路径用最近偶数规则舍入一次。修复逐段舍入把本应有限的总长变为Infinity、以及加法顺序造成距离矩阵不对称的问题；完整保留边或要求的叶间路径最终舍入为Infinity时仍报NumericOverflow，缺失传播与根stem规则继续适用。

公开边长和返回类型仍是Double；不恢复十进制解析前的无限精度，也不承诺换根切边或多条压缩边再次组合后具备超出binary64的表示能力。新增core/bigint仅用于内部精确累加，未引入第三方运行时依赖。

两项公开API反例、30组Python Fraction独立舍入向量和6141个有限binary64边界往返检查覆盖有限上界、真溢出、次正规数、最近偶数和不同加法顺序。参考生成器及精确分数回执保存在本轮报告；沿用既有研究树与外部参考数据。

## deep-repair-08 midpoint fix and diversity extension

中点位置使用选定路径的精确长度与双倍整数坐标比较，避免从已舍入的半直径逐边减法时漏掉小边。中点确在原顶点时复用该顶点，保留其标签和映射；落在边内时才把offset舍入为Double，包括半个最小次正规单位的最近偶数规则。公开diameter仍为Double，切边后的表示精度边界不变。新增公开API反例、11组对称路径和32组Fraction半长预期验证这一行为。

本轮新增的Faith PD功能是已建立的生态学度量，不宣称算法发明或MoonBit生态首创。生态检索发现BioSeqs已有树分析功能；本库侧重明确合同、贡献边报告和JS/Wasm-GC原生运行。当前扩展不增加树格式，也不修改已有API和合法输入范围。
