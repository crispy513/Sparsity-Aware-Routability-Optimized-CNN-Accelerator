# Synthesis Command Usage

This README describes how to run the parameterized Design Compiler synthesis flow.

The synthesis flow uses one shared Tcl script. You only need to specify the top module name, RTL source files, and optional output prefix from the Makefile command.

---

## Basic Command

```bash
make synthesize SYN_TOP=<top_module> SYN_SRC="<rtl_files>" SYN_OUT=<output_prefix>
```

### Arguments

| Argument | Required | Description |
|---|---:|---|
| `SYN_TOP` | Yes | Top module name to elaborate and synthesize. |
| `SYN_SRC` | Usually yes | RTL source file or source file list. |
| `SYN_OUT` | No | Output file prefix. If not specified, it defaults to `SYN_TOP`. |

---

## Important Path Rule

The Makefile runs Design Compiler inside the `build/` directory.

Therefore, RTL paths should usually start with `../`.

Correct:

```bash
make synthesize SYN_TOP=PE SYN_SRC=../src/PE_array/PE.sv
```

Wrong:

```bash
make synthesize SYN_TOP=PE SYN_SRC=src/PE_array/PE.sv
```

---

## Example Commands

### Synthesize `PE`

```bash
make synthesize SYN_TOP=PE SYN_SRC=../src/PE_array/PE.sv
```

This generates:

```text
syn/PE_timing_max_rpt.txt
syn/PE_timing_min_rpt.txt
syn/PE_area_rpt.txt
syn/PE_power_rpt.txt
syn/PE_syn.v
syn/PE_syn.sdf
```

---

### Synthesize `PE_origin`

```bash
make synthesize SYN_TOP=PE_origin SYN_SRC=../src/PE_array/PE_origin.sv SYN_OUT=PE_ori
```

This generates:

```text
syn/PE_ori_timing_max_rpt.txt
syn/PE_ori_timing_min_rpt.txt
syn/PE_ori_area_rpt.txt
syn/PE_ori_power_rpt.txt
syn/PE_ori_syn.v
syn/PE_ori_syn.sdf
```

---

### Synthesize `PE_array`

If the Tcl script already contains the full RTL file list for `PE_array`, you can run:

```bash
make synthesize SYN_TOP=PE_array SYN_OUT=PE_array
```

This generates:

```text
syn/PE_array_timing_max_rpt.txt
syn/PE_array_timing_min_rpt.txt
syn/PE_array_area_rpt.txt
syn/PE_array_power_rpt.txt
syn/PE_array_syn.v
syn/PE_array_syn.sdf
```

If you need to pass multiple RTL files manually, use quotes:

```bash
make synthesize SYN_TOP=PE_array SYN_SRC="../src/PE_array/PE.sv ../src/PE_array/PE_cluster.sv ../src/PE_array/PE_array.sv" SYN_OUT=PE_array
```

---

## Output Naming Rule

The output prefix is controlled by `SYN_OUT`.

If `SYN_OUT` is not specified, the script uses `SYN_TOP` as the output prefix.

For example:

```bash
make synthesize SYN_TOP=PE SYN_SRC=../src/PE_array/PE.sv
```

is equivalent to:

```bash
make synthesize SYN_TOP=PE SYN_SRC=../src/PE_array/PE.sv SYN_OUT=PE
```

The generated files follow this naming rule:

```text
syn/${SYN_OUT}_timing_max_rpt.txt
syn/${SYN_OUT}_timing_min_rpt.txt
syn/${SYN_OUT}_area_rpt.txt
syn/${SYN_OUT}_power_rpt.txt
syn/${SYN_OUT}_syn.v
syn/${SYN_OUT}_syn.sdf
```

---

## Shortcut Targets

The Makefile may also provide shortcut targets for common modules:

```bash
make synthesize_PE
make synthesize_PE_ori
make synthesize_PE_array
```

These targets should internally call the same parameterized synthesis flow.

---

## Notes

- `build/` and `syn/` are generated directories and should not be committed.
- If Design Compiler prints the Tcl commands while running, that is normal.
- Check the actual error message if synthesis fails, especially missing source paths or unset variables.
