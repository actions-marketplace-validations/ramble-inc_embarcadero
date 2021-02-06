#!/bin/sh -eux

echo "Arriving at Embarcadero..."

AUTHOR_USERNAME="$1"
AUTHOR_EMAIL="$2"
SRC_FILES="$3"
DEST_USERNAME="$4"
DEST_REPO="$5"
DEST_DIR="$6"
DEST_BRANCH=${7:-main}
CREATE_PR=${8:-false}
DEST_PR_BASE_BRANCH=${9:-main}

# input validation
if [ -z "$AUTHOR_USERNAME" ]
then
  echo '"author-email" must be defined'
  return -1
fi
if [ -z "$AUTHOR_EMAIL" ]
then
  echo 'author-email" must be defined'
  return -1
fi
if [ -z "$SRC_FILES" ]
then
  echo 'src-files" must be defined'
  return -1
fi
if [ -z "$DEST_USERNAME" ]
then
  echo 'dest-username" must be defined'
  return -1
fi
if [ -z "$DEST_REPO" ]
then
  echo 'dest-repo" must be defined'
  return -1
fi
if [ -z "$DEST_DIR" ]
then
  echo 'dest-dir" must be defined'
  return -1
fi

SRC_REPO_DIR=$(pwd)
DIST_REPO_DIR=$(mktemp -d)
COMMIT_URL="https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"

echo "Cloning $DEST_USERNAME/$DEST_REPO..."
git config --global user.name "$AUTHOR_USERNAME"
git config --global user.email "$AUTHOR_EMAIL"
git clone --single-branch "https://$ACCESS_TOKEN@github.com/$DEST_USERNAME/$DEST_REPO.git" "$DIST_REPO_DIR"
cd "$DIST_REPO_DIR"
git checkout -b $DEST_BRANCH

echo "Copying files to $DEST_USERNAME/$DEST_REPO..."
mkdir -p $DIST_REPO_DIR/$DEST_DIR
cp -r "$SRC_REPO_DIR/$SRC_FILES" "$DIST_REPO_DIR/$DEST_DIR"

git add .
git status

# avoid failing with "nothing to commit, working tree clean"
if (git diff-index --quiet HEAD)
then
  echo "nothing to commit, working tree clean"
  return 0
fi

echo "Committing to $DEST_USERNAME/$DEST_REPO..."
git commit -m "Update from $COMMIT_URL"

echo "Pushing to $DEST_USERNAME/$DEST_REPO@$DEST_BRANCH..."
git push -u origin "HEAD:$DEST_BRANCH"

if ($CREATE_PR)
then
  echo "Creating a PR $DEST_PR_BASE_BRANCH <- $DEST_BRANCH..."

  TITLE="[Embarcadero]: Update from $DEST_USERNAME/$DEST_REPO"
  BODY="## Base Commit\n$COMMIT_URL\n\n## Files\n- $DEST_DIR"

  PR_URL=$(
    curl --fail \
      -X POST \
      -u "$AUTHOR_USERNAME:$ACCESS_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/$DEST_USERNAME/$DEST_REPO/pulls \
      -d "{\"base\":\"$DEST_PR_BASE_BRANCH\",\"head\":\"$DEST_BRANCH\",\"title\":\"$TITLE\",\"body\":\"$BODY\"}" \
    | tr -d "\n" \
    | jq .html_url
  )

  if [ "$PR_URL" == "null" ]
  then
    echo "Failed to create a PR"
    return -1
  fi

  echo "Created $PR_URL"
fi
