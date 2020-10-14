#!/bin/sh -eux

echo "Arriving at Embarcadero..."

AUTHOR_USERNAME="$1"
AUTHOR_EMAIL="$2"
SRC_FILES="$3"
DEST_USERNAME="$4"
DEST_REPO="$5"
DEST_DIR="$6"
DEST_BRANCH=${7:-main}

# input validation
if [ -z "$AUTHOR_USERNAME" ]
then
  echo "\"author-username\" must be defined"
  return -1
fi
if [ -z "$AUTHOR_EMAIL" ]
then
  echo "\"author-email\" must be defined"
  return -1
fi
if [ -z "$SRC_FILES" ]
then
  echo "\"src-files\" must be defined"
  return -1
fi
if [ -z "$DEST_USERNAME" ]
then
  echo "\"dest-username\" must be defined"
  return -1
fi
if [ -z "$DEST_REPO" ]
then
  echo "\"dest-repo\" must be defined"
  return -1
fi
if [ -z "$DEST_DIR" ]
then
  echo "\"dest-dir\" must be defined"
  return -1
fi

CLONE_DIR=$(mktemp -d)

echo "Cloning $DEST_USERNAME/$DEST_REPO..."
git config --global user.name "$AUTHOR_USERNAME"
git config --global user.email "$AUTHOR_EMAIL"
git clone --single-branch --branch "$DEST_BRANCH" "https://$ACCESS_TOKEN@github.com/$DEST_USERNAME/$DEST_REPO.git" "$CLONE_DIR"
ls -la "$CLONE_DIR"

echo "Copying files to $DEST_USERNAME/$DEST_REPO..."
mkdir -p $CLONE_DIR/$DEST_DIR
cp -r $SRC_FILES "$CLONE_DIR/$DEST_DIR"
cd "$CLONE_DIR"
ls -la

git add .
git status

# avoid failing with "nothing to commit, working tree clean"
if (git diff-index --quiet HEAD)
then
  echo "nothing to commit, working tree clean"
  return -1
fi

echo "Committing to $DEST_USERNAME/$DEST_REPO..."
git commit -m "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"

echo "Pushing to $DEST_USERNAME/$DEST_REPO@$DEST_BRANCH..."
git push origin "$DEST_BRANCH"
