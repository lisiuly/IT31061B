import re

file_path = r'e:\project\IT31061B\DEMO\LCD\LCD_Display.tab'
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Lines 302 to 454 (0-indexed: 301 to 454)
subset = lines[301:454]

results = []
current_symbol = "None"

for line in subset:
    # Handle comments - remove everything after ';'
    clean_line = line.split(';')[0].strip()
    if not clean_line:
        # If the line was entirely a comment or empty, skipped.
        # But we need to be careful not to lose the current_symbol if the next line is the conversion.
        continue
    
    # Check for symbol definition (must be at start or followed by equ)
    # The symbol usually ends with a colon or is followed by 'equ'
    symbol_match = re.match(r'^(\w+):', clean_line)
    if symbol_match:
        current_symbol = symbol_match.group(1)
    elif ' equ ' in clean_line:
        # Check if there's a label before equ
        equ_match = re.match(r'^(\w+)\s+equ', clean_line)
        if equ_match:
            # Check if it's an alias (e.g., T_TeNeg: equ T_InTeNeg)
            # Aliases are ignored for "duplicates" as per prompt.
            # Usually, an alias line doesn't have LCDConvert or %LCD7S.
            pass

    # Extract comX,segYY from %LCD7S or LCDConvert lines
    # Only if the line actually contains the points
    if '%LCD7S' in line or 'LCDConvert' in line:
        # Make sure we don't extract from commented out segments
        # Re-check clean_line
        points = re.findall(r'com\d+,seg\d+', clean_line)
        for p in points:
            results.append((p, current_symbol))

# Count occurrences
point_map = {}
for p, sym in results:
    if p not in point_map:
        point_map[p] = []
    if sym not in point_map[p]:
        point_map[p].append(sym)

# Filter duplicates
duplicates = {p: syms for p, syms in point_map.items() if len(syms) > 1}

for p, syms in sorted(duplicates.items()):
    print(f"{p}: {', '.join(syms)}")
