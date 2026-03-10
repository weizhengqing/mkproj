#!/bin/zsh

# ABINIT项目目录结构自动生成脚本
# 版本: 2.2

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

OPT_RPT=false
OPT_DOC=false
OPT_REF=false
OPT_PROC=false
YES_ALL=false
SCRIPT_NAME=$(basename "$0")   # zsh 函数内 $0 为函数名，提前保存脚本名

# 显示使用说明
show_usage() {
    local script_name="$SCRIPT_NAME"
    echo "ABINIT项目目录结构生成器 v2.2"
    echo ""
    echo "使用方法:"
    echo "  zsh ${script_name} <项目名称> [目标路径] [选项]"
    echo ""
    echo "选项:"
    echo "  --with-rpt    创建 rpt/ (报告) 目录"
    echo "  --with-doc    创建 doc/ (文档) 目录"
    echo "  --with-ref    创建 ref/ (参考文献) 目录"
    echo "  --with-proc   创建 proc/ (数据处理) 目录"
    echo "  --yes-all     创建所有可选目录，跳过询问"
    echo "  -h, --help    显示本帮助信息"
    echo ""
    echo "固定生成的目录:"
    echo "  calc/         计算任务目录"
    echo "  str/          结构文件目录"
    echo "    ├── initial/    初始结构"
    echo "    ├── template/   结构模板"
    echo "    └── opt/        优化后结构"
    echo "  dat/          原始数据目录"
    echo "  util/         脚本工具目录"
    echo "  viz/          可视化目录"
    echo ""
    echo "可选目录 (终端交互勾选):"
    echo "  rpt/          报告目录"
    echo "  doc/          文档目录"
    echo "  ref/          参考文献目录"
    echo "  proc/         数据处理目录"
    echo "    ├── pre/      预处理"
    echo "    └── post/     后处理"
    echo ""
    echo "示例:"
    echo "  zsh ${script_name} TiO2_Study"
    echo "  zsh ${script_name} TiO2_Study /path/to/dir --with-doc --with-rpt"
    echo "  zsh ${script_name} TiO2_Study --yes-all"
}

# 验证项目名称
validate_project_name() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        print_error "项目名称不能为空"
        return 1
    fi
    
    # 检查特殊字符
    if echo "$project_name" | grep -q '[/\\:*?"<>|]'; then
        print_error "项目名称不能包含以下特殊字符: / \\ : * ? \" < > |"
        return 1
    fi
    
    return 0
}

# ──────────────────────────────────────────────
# 终端 TUI 勾选菜单（纯 zsh，兼容 macOS / Linux）
# ↑↓ 移动光标  空格 勾选/取消  Enter 确认
#
# 修复说明：
#   zsh 嵌套函数无法访问外层 local 变量（无闭包），
#   需要内联绘制逻辑，避免嵌套函数。
# ──────────────────────────────────────────────
ask_via_terminal_menu() {
    # zsh 数组从 1 开始
    local opt1="rpt   实验报告 / 结果汇总"
    local opt2="doc   项目文档 / 说明"
    local opt3="ref   参考文献 / 资料"
    local opt4="proc  数据处理 (含 pre/ post/ 子目录)"
    local s1=0 s2=0 s3=0 s4=0   # 0=未选, 1=已选
    local cur=1                  # 当前高亮行（1~4）
    local nopt=4
    # 菜单占行数：1(空行) + 1(标题) + 1(空行) + 4(选项) + 1(空行) = 8
    local total_lines=8
    local key k2 k3

    # ── 内联绘制函数（取代闭包）──────────────────
    # 用法：_tui_draw <cur> <s1> <s2> <s3> <s4> <redraw:0|1>
    #   redraw=0 首次绘制；redraw=1 先上移 total_lines 再清屏重绘
    _tui_draw() {
        local _cur=$1 _s1=$2 _s2=$3 _s3=$4 _s4=$5 _redraw=$6
        local _i _box

        if (( _redraw )); then
            printf "\033[%dA\033[J" "$total_lines"   # 上移 + 清屏
        fi

        echo ""
        printf "  ${CYAN}可选目录 (↑↓/hjkl 移动  空格 勾选  Enter 确认)：${NC}\n"
        echo ""

        local _states=($_s1 $_s2 $_s3 $_s4)
        local _opts=("$opt1" "$opt2" "$opt3" "$opt4")
        for _i in 1 2 3 4; do
            if (( _states[$_i] )); then
                _box="${GREEN}[✓]${NC}"
            else
                _box="[ ]"
            fi
            if (( _i == _cur )); then
                printf "  ${CYAN}▶${NC} %b %s\n" "$_box" "${_opts[$_i]}"
            else
                printf "    %b %s\n" "$_box" "${_opts[$_i]}"
            fi
        done
        echo ""
    }

    # 首次绘制
    _tui_draw $cur $s1 $s2 $s3 $s4 0

    tput civis 2>/dev/null  # 隐藏光标

    while true; do
        IFS= read -rsk1 key
        if [[ "$key" == $'\x1b' ]]; then
            IFS= read -rsk1 -t0.1 k2
            IFS= read -rsk1 -t0.1 k3
            if [[ "$k2" == '[' ]]; then
                case "$k3" in
                    'A') (( cur-- )); (( cur < 1    )) && cur=$nopt ;;
                    'B') (( cur++ )); (( cur > nopt )) && cur=1    ;;
                esac
                _tui_draw $cur $s1 $s2 $s3 $s4 1
            fi
        elif [[ "$key" == 'k' || "$key" == 'K' || "$key" == 'h' || "$key" == 'H' ]]; then
            (( cur-- )); (( cur < 1    )) && cur=$nopt
            _tui_draw $cur $s1 $s2 $s3 $s4 1
        elif [[ "$key" == 'j' || "$key" == 'J' || "$key" == 'l' || "$key" == 'L' ]]; then
            (( cur++ )); (( cur > nopt )) && cur=1
            _tui_draw $cur $s1 $s2 $s3 $s4 1
        elif [[ "$key" == ' ' ]]; then
            case $cur in
                1) (( s1 = s1 ? 0 : 1 )) ;;
                2) (( s2 = s2 ? 0 : 1 )) ;;
                3) (( s3 = s3 ? 0 : 1 )) ;;
                4) (( s4 = s4 ? 0 : 1 )) ;;
            esac
            _tui_draw $cur $s1 $s2 $s3 $s4 1
        elif [[ "$key" == $'\n' || "$key" == $'\r' || -z "$key" ]]; then
            break
        fi
    done

    tput cnorm 2>/dev/null  # 恢复光标
    unfunction _tui_draw 2>/dev/null

    (( s1 )) && OPT_RPT=true  || true
    (( s2 )) && OPT_DOC=true  || true
    (( s3 )) && OPT_REF=true  || true
    (( s4 )) && OPT_PROC=true || true
}

# ──────────────────────────────────────────────
# 询问可选目录
# ──────────────────────────────────────────────
ask_optional_dirs() {
    if [ "$YES_ALL" = true ]; then
        OPT_RPT=true; OPT_DOC=true; OPT_REF=true; OPT_PROC=true
        print_info "--yes-all 已设置，将创建所有可选目录"
        return
    fi

    if [ "$OPT_RPT" = true ] || [ "$OPT_DOC" = true ] || [ "$OPT_REF" = true ] || [ "$OPT_PROC" = true ]; then
        print_info "已通过命令行参数指定可选目录，跳过询问"
        return
    fi

    ask_via_terminal_menu

    echo -e "${CYAN}已选择：${NC}"
    [ "$OPT_RPT"  = true ] && echo "  ✓ rpt/"  || echo "  ✗ rpt/"
    [ "$OPT_DOC"  = true ] && echo "  ✓ doc/"  || echo "  ✗ doc/"
    [ "$OPT_REF"  = true ] && echo "  ✓ ref/"  || echo "  ✗ ref/"
    [ "$OPT_PROC" = true ] && echo "  ✓ proc/" || echo "  ✗ proc/"
    echo ""
}

# 创建目录结构
create_directory_structure() {
    local base_dir="$1"

    print_info "创建核心目录结构..."

    local fixed_dirs=(
        "calc"
        "str/initial"
        "str/template"
        "str/opt"
        "dat"
        "util"
        "viz"
    )

    for dir in "${fixed_dirs[@]}"; do
        mkdir -p "${base_dir}/${dir}"
        print_success "创建目录: ${dir}"
    done

    echo ""
    print_info "处理可选目录..."

    if [ "$OPT_RPT" = true ]; then
        mkdir -p "${base_dir}/rpt"
        print_success "创建目录: rpt"
    else
        print_warning "跳过目录:  rpt"
    fi

    if [ "$OPT_DOC" = true ]; then
        mkdir -p "${base_dir}/doc"
        print_success "创建目录: doc"
    else
        print_warning "跳过目录:  doc"
    fi

    if [ "$OPT_REF" = true ]; then
        mkdir -p "${base_dir}/ref"
        print_success "创建目录: ref"
    else
        print_warning "跳过目录:  ref"
    fi

    if [ "$OPT_PROC" = true ]; then
        mkdir -p "${base_dir}/proc/pre"
        mkdir -p "${base_dir}/proc/post"
        print_success "创建目录: proc/pre"
        print_success "创建目录: proc/post"
    else
        print_warning "跳过目录:  proc"
    fi
}

# 创建示例脚本文件
create_example_scripts() {
    local base_dir="$1"
    
    print_info "创建示例脚本文件..."
    
    cat > "${base_dir}/util/abinit_input_config.py" << 'EOF'
import warnings
warnings.filterwarnings("ignore")  # to get rid of deprecation warnings

import os
import glob
import argparse
from pathlib import Path
from abipy.abilab import AbinitInput


def get_pseudo_for_structure(structure_path, pseudo_dir):
    """
    根据结构文件自动获取对应元素的赝势文件
    
    Args:
        structure_path: VASP 结构文件路径
        pseudo_dir: 赝势文件目录
    
    Returns:
        赝势文件路径列表
    """
    from pymatgen.io.vasp import Poscar
    
    # 读取结构文件获取元素列表
    poscar = Poscar.from_file(structure_path)
    elements = [str(element) for element in poscar.structure.composition.elements]
    elements = sorted(set(elements))  # 去重并排序
    
    # 构建赝势文件路径列表
    # 假设赝势文件命名格式为 Element.psp8
    pseudo_files = []
    for element in elements:
        pseudo_file = os.path.join(pseudo_dir, f"{element}.psp8")
        if os.path.exists(pseudo_file):
            pseudo_files.append(pseudo_file)
        else:
            # 如果找不到 .psp8，尝试其他常见格式
            for ext in ['.psp', '.xml', '.upf']:
                alt_pseudo = os.path.join(pseudo_dir, f"{element}{ext}")
                if os.path.exists(alt_pseudo):
                    pseudo_files.append(alt_pseudo)
                    break
            else:
                raise FileNotFoundError(f"Pseudopotential file not found for element {element} in {pseudo_dir}")
    
    return pseudo_files


def create_mainsim_script(calc_dir):
    """
    创建 mainsim 集群的提交脚本
    
    Args:
        calc_dir: 计算目录路径
    """
    script_content = """#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=24
#SBATCH --cpus-per-task=1
#SBATCH --job-name=Job
#SBATCH --output=job_%j.out
#SBATCH --mail-user=zhengqing.wei@physik.tu-chemnitz.de
#SBATCH --mail-type=START,END,FAIL,TIME_LIMIT
#SBATCH --partition=cpu
###SBATCH --nodelist=simep05
###SBATCH --exclude=simep04
#SBATCH --error=error

module unload openmpi
module load abinit/9.10.3/openmpi3-mkl
mpirun abinit run.abi > log
"""
    
    script_path = os.path.join(calc_dir, "mainsim.sh")
    with open(script_path, 'w') as f:
        f.write(script_content)
    
    # 添加可执行权限
    os.chmod(script_path, 0o755)
    print(f"  Created: mainsim.sh")


def create_barnard_script(calc_dir):
    """
    创建 barnard 集群的提交脚本
    
    Args:
        calc_dir: 计算目录路径
    """
    script_content = """#!/bin/bash

#SBATCH --time=5-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=64
#SBATCH --cpus-per-task=1
#SBATCH --job-name=Job
#SBATCH --output=job_%j.out
#SBATCH --mail-user=zhengqing.wei@mailbox.tu-dresden.de
#SBATCH --mail-type=START,END,FAIL,TIME_LIMIT
#SBATCH --partition=barnard
#SBATCH --account=p_structures
###SBATCH --nodelist=simep05
###SBATCH --exclude=simep04
#SBATCH --error=error

module load release/24.10
module load GCC/13.2.0
module load OpenMPI/4.1.6
module load ABINIT/10.0.9

mpirun abinit run.abi >> log
"""
    
    script_path = os.path.join(calc_dir, "barnard.sh")
    with open(script_path, 'w') as f:
        f.write(script_content)
    
    # 添加可执行权限
    os.chmod(script_path, 0o755)
    print(f"  Created: barnard.sh")


def create_abinit_input(structure_file, calc_dir, pseudo_dir):
    """
    为单个结构创建 ABINIT 输入文件
    
    Args:
        structure_file: 结构文件路径
        calc_dir: 计算目录路径
        pseudo_dir: 赝势文件目录
    """
    from pymatgen.io.vasp import Poscar
    from abipy.core.structure import Structure
    
    # 获取对应的赝势文件路径
    pseudos = get_pseudo_for_structure(structure_file, pseudo_dir)
    
    # 创建 AbinitInput 对象
    inp = AbinitInput(structure=structure_file, pseudos=pseudos)
    
    # 读取 abipy 生成的结构，获取元素类型顺序
    abipy_structure = Structure.from_file(structure_file)
    
    # 获取元素类型列表（按照 abipy 内部的顺序）
    # types_of_specie 返回的是按照 typat 顺序排列的元素
    element_types = abipy_structure.types_of_specie
    
    # 生成赝势文件名列表（顺序与 znucl 对应）
    pseudo_filenames = [f"{str(elem)}.psp8" for elem in element_types]
    
    # 设置基本参数
    inp.set_vars(
        # 晶格检查设置
        chkprim=0,        # 不检查原胞是否为原始晶胞
        chksymbreak=0,    # 关闭k点网格对称性检查
        
        # 平面波与k点取样
        ecut=30,          # 截断能 (Ha)
        kptopt=1,         # Γ中心网格
        nshiftk=1,        # k点网格偏移数量
        shiftk=[0.5, 0.5, 0.0],  # k点网格偏移
        kptrlatt=[[6, 0, 0], [0, 6, 0], [0, 0, 2]],  # k-point 坐标矩阵
        
        # 自洽场计算 (SCF cycle)
        nstep=300,        # 最大迭代步数
        toldfe=1.0e-7,    # 能量收敛标准 (Ha)
        iscf=17,          # 线性混合 + Pulay 技术
        npulayit=7,       # Pulay 迭代次数上限
        
        # 介电混合参数 (适用于含真空体系)
        iprcel=45,        # 预处理选项
        diemix=0.5,       # 介电混合参数
        diemac=1000.0,    # 宏观介电常数
        dielng=5.0,       # 介电长度
        
        # 电子结构参数设置
        nband=82,         # 能带数目
        occopt=7,         # 费米-狄拉克分布
        tsmear=0.03,      # 电子温度 (Ha)
        
        # 几何优化
        optcell=0,        # 固定晶格，不优化
        ionmov=2,         # BFGS 或阻尼动力学方法
        ntime=300,        # 最大步数
        dilatmx=1.15,     # 步长限制
        ecutsm=0.5,       # 光滑能量截断，改善力的连续性
        
        # 力收敛准则
        tolmxf=0,         # 最大力门限关闭
        tolmxde=1.0e-4,   # 总能变化门限 (Ha)
        
        # 输出与文件控制
        prtwf=0,          # 不输出波函数
        prtden=0,         # 不输出电子密度
        prtdos=1,         # 输出态密度
        enunit=2,         # 能量单位: eV
        
        # 使用环境变量指定赝势目录
        pp_dirpath="$PSEUDOS",
        
        # 明确指定赝势文件名（顺序与 znucl 一致）
        pseudos=", ".join([f'"{pf}"' for pf in pseudo_filenames]),
    )
    
    # 写入 run.abi 文件
    output_file = os.path.join(calc_dir, "run.abi")
    inp.write(filepath=output_file)
    print(f"  Created: run.abi")


def create_batch_submit_script(script_dir, calculations_dir, cluster_type):
    """
    创建批量提交脚本
    
    Args:
        script_dir: 脚本目录路径
        calculations_dir: 计算目录路径
        cluster_type: 集群类型 ('mainsim', 'barnard', 或 'both')
    """
    # 根据集群类型确定要生成的脚本
    scripts_to_create = []
    
    if cluster_type in ['mainsim', 'both']:
        scripts_to_create.append(('mainsim', 'submit_all_mainsim.sh'))
    
    if cluster_type in ['barnard', 'both']:
        scripts_to_create.append(('barnard', 'submit_all_barnard.sh'))
    
    for cluster, script_name in scripts_to_create:
        script_content = f"""#!/bin/bash

# 批量提交脚本 - {cluster.upper()} 集群
# 生成时间: {os.popen('date').read().strip()}

# 设置颜色输出
GREEN='\\033[0;32m'
RED='\\033[0;31m'
YELLOW='\\033[1;33m'
NC='\\033[0m' # No Color

echo "========================================"
echo "批量提交 ABINIT 任务到 {cluster.upper()} 集群"
echo "========================================"
echo ""

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${{BASH_SOURCE[0]}}" )" && pwd )"

# 获取计算目录的相对路径（相对于脚本目录）
CALC_DIR="$SCRIPT_DIR/../2_calculations"

# 计数器
TOTAL=0
SUCCESS=0
FAILED=0

# 遍历所有子目录
for dir in "$CALC_DIR"/*/; do
    if [ -d "$dir" ]; then
        dirname=$(basename "$dir")
        
        # 检查是否存在提交脚本
        if [ -f "${{dir}}{cluster}.sh" ]; then
            echo -n "提交任务: $dirname ... "
            
            # 进入目录并提交任务
            cd "$dir"
            
            # 提交任务并捕获输出
            output=$(sbatch {cluster}.sh 2>&1)
            exit_code=$?
            
            if [ $exit_code -eq 0 ]; then
                # 提取作业ID
                job_id=$(echo "$output" | grep -oP '(?<=Submitted batch job )\\d+' || echo "$output")
                echo -e "${{GREEN}}✓ 成功${{NC}} (Job ID: $job_id)"
                ((SUCCESS++))
            else
                echo -e "${{RED}}✗ 失败${{NC}} - $output"
                ((FAILED++))
            fi
            
            ((TOTAL++))
            
            # 返回脚本目录
            cd - > /dev/null
            
            # 添加短暂延迟避免过快提交
            sleep 0.5
        else
            echo -e "${{YELLOW}}⊗ 跳过${{NC}}: $dirname (未找到 {cluster}.sh)"
        fi
    fi
done

echo ""
echo "========================================"
echo "提交完成!"
echo "总计: $TOTAL 个任务"
echo -e "成功: ${{GREEN}}$SUCCESS${{NC}} 个"
if [ $FAILED -gt 0 ]; then
    echo -e "失败: ${{RED}}$FAILED${{NC}} 个"
fi
echo "========================================"
echo ""
echo "使用以下命令查看任务状态:"
echo "  squeue -u $USER"
echo ""
echo "使用以下命令取消所有任务:"
echo "  scancel -u $USER"
"""
        
        script_path = os.path.join(script_dir, script_name)
        with open(script_path, 'w') as f:
            f.write(script_content)
        
        # 添加可执行权限
        os.chmod(script_path, 0o755)
        
        print(f"  Created batch submit script: {script_name}")


def main():
    """
    主函数：遍历所有结构文件并创建计算目录和输入文件
    """
    # 设置参数解析
    parser = argparse.ArgumentParser(description='Generate ABINIT input files and job scripts')
    parser.add_argument('--cluster', type=str, choices=['mainsim', 'barnard', 'both'], 
                        default='both', help='Target cluster (mainsim, barnard, or both)')
    args = parser.parse_args()
    
    # 获取当前脚本所在目录的父目录（项目根目录）
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    
    # 定义路径
    structures_dir   = os.path.join(project_root, "str", "initial")
    calculations_dir = os.path.join(project_root, "calc")
    
    # 检查赝势目录
    if "PSEUDOS" not in os.environ:
        print("Error: PSEUDOS environment variable is not set!")
        print("Please set it to your pseudopotential directory path.")
        return
    
    pseudo_dir = os.environ["PSEUDOS"]
    
    # 确保计算目录存在
    os.makedirs(calculations_dir, exist_ok=True)
    
    # 查找所有 VASP 文件
    vasp_files = glob.glob(os.path.join(structures_dir, "*.vasp"))
    
    if not vasp_files:
        print(f"No .vasp files found in {structures_dir}")
        return
    
    print(f"Found {len(vasp_files)} structure file(s)")
    print(f"Target cluster(s): {args.cluster}")
    print("-" * 60)
    
    # 遍历每个结构文件
    successful_count = 0
    for vasp_file in vasp_files:
        # 获取文件名（不含扩展名）
        basename = os.path.splitext(os.path.basename(vasp_file))[0]
        
        print(f"\nProcessing: {basename}")
        
        # 创建对应的计算目录
        calc_dir = os.path.join(calculations_dir, basename)
        os.makedirs(calc_dir, exist_ok=True)
        print(f"  Directory: {calc_dir}")
        
        try:
            # 创建 ABINIT 输入文件
            create_abinit_input(vasp_file, calc_dir, pseudo_dir)
            
            # 根据参数创建相应的提交脚本
            if args.cluster in ['mainsim', 'both']:
                create_mainsim_script(calc_dir)
            
            if args.cluster in ['barnard', 'both']:
                create_barnard_script(calc_dir)
                
            print(f"  ✓ Successfully processed {basename}")
            successful_count += 1
            
        except Exception as e:
            print(f"  ✗ Error processing {basename}: {str(e)}")
    
    print("\n" + "=" * 60)
    print("All structures processed!")
    print(f"Calculation directories created in: {calculations_dir}")
    
    # 如果有成功处理的文件，创建批量提交脚本
    if successful_count > 0:
        print("\n" + "-" * 60)
        print("Creating batch submission scripts...")
        create_batch_submit_script(script_dir, calculations_dir, args.cluster)
        
        print("\n" + "=" * 60)
        print("Batch submission scripts created in: " + script_dir)
        print("\nTo submit all jobs, run:")
        
        if args.cluster in ['mainsim', 'both']:
            print(f"  bash {os.path.join(script_dir, 'submit_all_mainsim.sh')}")
        
        if args.cluster in ['barnard', 'both']:
            print(f"  bash {os.path.join(script_dir, 'submit_all_barnard.sh')}")
        
        print("=" * 60)


if __name__ == "__main__":
    main()
EOF

    print_success "创建文件: util/abinit_input_config.py"

    cat > "${base_dir}/util/create_structure.py" << 'EOF'
"""创建Al(111)表面吸附不同位点氧原子的结构文件并用VESTA可视化"""

import os
import subprocess

from ase import Atoms
from ase.build import add_adsorbate, fcc111
from ase.io import write


# =============================================================================
# 1. 创建金属结构
# =============================================================================

al_111 = fcc111('Al', size=(2, 2, 7), vacuum=15.0)

# 查看结构信息（可选）
# print(f"原子数: {len(al_111)}")
# print(f"晶胞参数: {al_111.get_cell()}")
# print(f"化学式: {al_111.get_chemical_formula()}")


# =============================================================================
# 2. 创建吸附物结构
# =============================================================================

oxygen = Atoms('O')


# =============================================================================
# 3. 结构操作
# =============================================================================

# 复制基底结构用于不同的吸附位点
al_111_top = al_111.copy()
al_111_bridge = al_111.copy()
al_111_fcc = al_111.copy()
al_111_hcp = al_111.copy()

add_adsorbate(al_111_top, 'O', height=2.0, position='ontop')
add_adsorbate(al_111_bridge, 'O', height=2.0, position='bridge')
add_adsorbate(al_111_fcc, 'O', height=2.0, position='fcc')
add_adsorbate(al_111_hcp, 'O', height=2.0, position='hcp')


# =============================================================================
# 4. 保存结构文件
# =============================================================================

output_dir = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'str', 'initial')
)
os.makedirs(output_dir, exist_ok=True)

for site, struct in [('ontop', al_111_top), ('bridge', al_111_bridge),
                     ('fcc',   al_111_fcc),  ('hcp',   al_111_hcp)]:
    name     = f'al_111_O_{site}'
    cif_path = os.path.join(output_dir, f'{name}.cif')
    write(cif_path, struct)
    print(f'Saved: {cif_path}')
    try:
        subprocess.Popen(['open', '-a', 'VESTA', cif_path])
        print(f'  Opened in VESTA: {name}.cif')
    except Exception as e:
        print(f'  VESTA open failed: {e}')
EOF

    print_success "创建文件: util/create_structure.py"
}

show_completion_info() {
    local base_dir="$1"
    local project_name="$2"

    echo ""
    echo "=============================================="
    print_success "项目目录创建完成！"
    echo "=============================================="
    echo ""
    echo "项目位置: $(realpath "$base_dir")"
    echo ""
    echo "目录结构预览:"
    if command -v tree &>/dev/null; then
        tree "$base_dir" -L 2
    else
        find "$base_dir" -type d | sort | sed "s|$(realpath "$base_dir")||" | sed 's/^/  /'
    fi
    echo ""
    echo "下一步操作："
    echo "  1. 进入项目目录:  cd \"$(realpath "$base_dir")\""
    echo "  2. 添加结构文件:  复制 .vasp 文件到 str/initial/"
    echo "  3. 生成计算输入:  python util/abinit_input_config.py"
    echo ""
    print_success "一切就绪，开始使用吧！"
}

validate_path() {
    local target_path="$1"
    if [ ! -d "$target_path" ]; then
        print_error "指定的路径 '$target_path' 不存在"
        return 1
    fi
    if [ ! -w "$target_path" ]; then
        print_error "没有写入权限到路径 '$target_path'"
        return 1
    fi
    return 0
}

# ──────────────────────────────────────────────
# 主函数
# ──────────────────────────────────────────────
main() {
    echo "=============================================="
    echo "    ABINIT 项目目录结构生成器 v2.2"
    echo "=============================================="
    echo ""

    if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_usage; exit 0
    fi

    PROJECT_NAME=""
    TARGET_PATH="."
    POSITIONAL=()

    for arg in "$@"; do
        case $arg in
            --with-rpt)  OPT_RPT=true ;;
            --with-doc)  OPT_DOC=true ;;
            --with-ref)  OPT_REF=true ;;
            --with-proc) OPT_PROC=true ;;
            --yes-all)   YES_ALL=true ;;
            --*)
                print_error "未知选项: $arg"
                show_usage; exit 1 ;;
            *) POSITIONAL+=("$arg") ;;
        esac
    done

    PROJECT_NAME="${POSITIONAL[1]}"
    [ ${#POSITIONAL[@]} -ge 2 ] && TARGET_PATH="${POSITIONAL[2]}"

    if ! validate_project_name "$PROJECT_NAME"; then exit 1; fi

    if [ "$TARGET_PATH" != "." ]; then
        if ! validate_path "$TARGET_PATH"; then exit 1; fi
        print_info "目标路径: $TARGET_PATH"
    fi

    ask_optional_dirs

    CURRENT_DATE=$(date +%Y%m%d)
    if [ "$TARGET_PATH" = "." ]; then
        PROJECT_DIR="${PROJECT_NAME}_${CURRENT_DATE}"
    else
        PROJECT_DIR="${TARGET_PATH}/${PROJECT_NAME}_${CURRENT_DATE}"
    fi

    if [ -d "$PROJECT_DIR" ]; then
        print_warning "目录 '$PROJECT_DIR' 已存在"
        read -p "是否覆盖? (y/N): " -n 1 -r; echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "操作取消"; exit 0
        fi
        rm -rf "$PROJECT_DIR"
    fi

    print_info "创建项目: $PROJECT_NAME → $PROJECT_DIR"
    echo ""

    mkdir -p "$PROJECT_DIR"
    create_directory_structure "$PROJECT_DIR"
    echo ""
    create_example_scripts "$PROJECT_DIR"
    show_completion_info "$PROJECT_DIR" "$PROJECT_NAME"
}

main "$@"
