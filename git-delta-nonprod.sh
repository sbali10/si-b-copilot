#!/bin/bash

# Check if we are in a Git repository
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: Not a Git repository."
  exit 1
fi

# Function to get the commit ID before a specific number of days
get_commit_before_days() {
  local days=$1
  git rev-list -1 --before="$days days ago" HEAD
}

# Try to get the commit ID from 6 days ago
COMMIT_6_DAYS_AGO=$(get_commit_before_days 6)

# If no commit is found for 6 days ago, try 5, 4, 3, 2, and 1 days ago
if [ -z "$COMMIT_6_DAYS_AGO" ]; then
  echo "No commit found from 6 days ago, trying earlier dates..."
  for i in 5 4 3 2 1; do
    COMMIT=$(get_commit_before_days $i)
    if [ -n "$COMMIT" ]; then
      COMMIT_N_DAYS_AGO=$COMMIT
      echo "Commit found from $i days ago: $COMMIT_N_DAYS_AGO"
      break
    fi
  done
  if [ -z "$COMMIT_N_DAYS_AGO" ]; then
    echo "Error: No commits found from the last 6 days."
    exit 1
  fi
else
  COMMIT_N_DAYS_AGO=$COMMIT_6_DAYS_AGO
  echo "Commit found from 6 days ago: $COMMIT_N_DAYS_AGO"
fi

# Get the latest commit ID
LATEST_COMMIT=$(git rev-parse HEAD)

# Output the commits for reference
echo "Latest commit: $LATEST_COMMIT"
echo "Commit from $i days ago: $COMMIT_N_DAYS_AGO"

# Create the target directory
TARGET_DIR="weekly_delta"
mkdir -p "$TARGET_DIR"

# Extract the delta (newly added/changed lines only) and save them to their original files
echo "Processing changes..."
git diff $COMMIT_N_DAYS_AGO $LATEST_COMMIT --name-only | while read -r file; do
  # Skip binary files
  if file "$file" | grep -q "binary"; then
    echo "Skipping binary file: $file"
    continue
  fi
  
  # Generate the new file path in the target directory
  new_file="$TARGET_DIR/$file"
  mkdir -p "$(dirname "$new_file")"

  # Extract added and changed lines and save to the new file
  git diff $COMMIT_N_DAYS_AGO $LATEST_COMMIT -- "$file" \
    | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//' > "$new_file"

  echo "Processed: $file -> $new_file"
done

echo "All changes have been extracted to the '$TARGET_DIR' directory."

# Check the size of the metadata-folder and print in KB
METADATA_FOLDER="weekly_delta"
if [ -d "$METADATA_FOLDER" ]; then
  SIZE_KB=$(du -sk "$METADATA_FOLDER" | cut -f1)
  echo "Size of '$METADATA_FOLDER': $SIZE_KB KB"
else
  echo "Error: '$METADATA_FOLDER' directory does not exist."
fi