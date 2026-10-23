import os
import re

LIB_DIR = "lib"
OUTPUT_FILE = "app_map.md"

def generate_app_map():
    if not os.path.exists(LIB_DIR):
        print(f"Error: '{LIB_DIR}' directory not found.")
        return

    markdown_content = "# FLUTTER APP MAP (auto-generated)\n\n"

    # Walk through the lib directory
    for root, dirs, files in os.walk(LIB_DIR):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file).replace("\\", "/")
                
                # Read file content
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                        line_count = len(lines)
                        content = "".join(lines)
                except Exception as e:
                    print(f"Could not read {file_path}: {e}")
                    continue

                # Extract class names using regex
                classes = re.findall(r'class\s+([A-Za-z0-9_]+)', content)
                classes_str = ", ".join(classes) if classes else "None"

                # Append section to markdown
                markdown_content += f"## {file_path} ({line_count} lines)\n"
                markdown_content += f"- classes: {classes_str}\n"
                markdown_content += f"- uses (other project classes): \n" # Placeholder or custom extractor
                markdown_content += f"- supabase tables: \n"
                markdown_content += f"- rpc: \n"
                markdown_content += f"- storage buckets: \n"
                markdown_content += f"- realtime channels: \n"
                markdown_content += f"- auth calls: \n\n"

    # Write to app_map.md
    with open(OUTPUT_FILE, "w", encoding="utf-8") as out:
        out.write(markdown_content)
    
    print(f"Successfully updated '{OUTPUT_FILE}'!")

if __name__ == "__main__":
    generate_app_map()