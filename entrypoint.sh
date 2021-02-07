#!/bin/sh -eux

echo "Arriving at Embarcadero..."

AUTHOR_USERNAME="$1"
AUTHOR_EMAIL="$2"
MAPPINGS="$3"
DEST_USERNAME="$4"
DEST_REPO="$5"
DEST_BRANCH=${6:-main}
CREATE_PR=${7:-false}
DEST_PR_BASE_BRANCH=${8:-main}

# input validation
if [ -z "$AUTHOR_USERNAME" ]
then
  echo '"author-username" must be defined'
  return -1
fi
if [ -z "$AUTHOR_EMAIL" ]
then
  echo 'author-email" must be defined'
  return -1
fi
if [ -z "$MAPPINGS" ]
then
  echo 'mappings" must be defined'
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

SRC_REPO_DIR=$(pwd)
DIST_REPO_DIR=$(mktemp -d)
COMMIT_URL="https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"

echo "Cloning $DEST_USERNAME/$DEST_REPO..."
git config --global user.name "$AUTHOR_USERNAME"
git config --global user.email "$AUTHOR_EMAIL"
git clone --single-branch "https://$ACCESS_TOKEN@github.com/$DEST_USERNAME/$DEST_REPO.git" "$DIST_REPO_DIR"
cd "$DIST_REPO_DIR"
git checkout -b $DEST_BRANCH

for JSON in $(echo $MAPPINGS | jq -c .[])
do
  SRC=$(echo $JSON | jq -r .src)
  DEST=$(echo $JSON | jq -r .dest)
  echo "Copying $SRC_REPO_DIR/$SRC to $DIST_REPO_DIR/$DEST..."
  mkdir -p $DIST_REPO_DIR/$DEST
  cp -r $SRC_REPO_DIR/$SRC $DIST_REPO_DIR/$DEST
done

git add -N .
CHANGED_FILES=$(git diff --name-only)
git add .
git status

# avoid failing with "nothing to commit, working tree clean"
if [ -z "$CHANGED_FILES" ]
then
  echo "nothing to commit, working tree clean"
  return 0
fi

echo "Committing to $DEST_USERNAME/$DEST_REPO..."
git commit -m "Update from $COMMIT_URL"

echo "Pushing to $DEST_USERNAME/$DEST_REPO@$DEST_BRANCH..."
git push -u origin "HEAD:$DEST_BRANCH"

if "$CREATE_PR"
then
  echo "Creating a PR $DEST_PR_BASE_BRANCH <- $DEST_BRANCH..."

  TITLE="[Embarcadero]: Update from $DEST_USERNAME/$DEST_REPO"
  BODY="## Base Commit\n$COMMIT_URL\n\n## Files\n"
  for FILE in $CHANGED_FILES
  do
    BODY="${BODY}\n- [$FILE](https://github.com/$DEST_USERNAME/$DEST_REPO/blob/$DEST_BRANCH/$FILE)"
  done

  PR_URL=$(
    curl --fail \
      -X POST \
      -u "$AUTHOR_USERNAME:$ACCESS_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/$DEST_USERNAME/$DEST_REPO/pulls \
      -d "{\"base\":\"$DEST_PR_BASE_BRANCH\",\"head\":\"$DEST_BRANCH\",\"title\":\"$TITLE\",\"body\":\"$BODY\"}" \
    | tr -d "\n" \
    | jq -r .html_url
  )

  if [ "$PR_URL" == "null" ]
  then
    echo "Failed to create a PR"
    return -1
  fi

  echo "Created $PR_URL"
fi
