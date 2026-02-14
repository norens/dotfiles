#!/bin/bash

# Script for auto-approving, merging PRs, deleting branches, and validations
# Usage: ./merge_pr.sh <PR_ID>

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
  echo "❌ Error: GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/ or brew install gh"
  exit 1
fi

# Check if the user is authenticated in GitHub CLI
if ! gh auth status &> /dev/null; then
  echo "❌ Error: You are not authenticated in GitHub CLI. Log in using:"
  echo "   gh auth login"
  exit 1
fi

# Check if PR ID is provided
if [ -z "$1" ]; then
  echo "❌ Error: No pull request ID provided."
  echo "Usage: $0 <PR_ID>"
  exit 1
fi

PR_ID=$1

# Check if the pull request exists
if ! gh pr view "$PR_ID" &> /dev/null; then
  echo "❌ Error: Pull request with ID $PR_ID not found."
  exit 1
fi

# Retrieve PR details
PR_STATE=$(gh pr view "$PR_ID" --json state -q '.state')
BRANCH=$(gh pr view "$PR_ID" --json headRefName -q '.headRefName')
APPROVED_BY=$(gh pr view "$PR_ID" --json reviews -q '.reviews[].author.login' | tr '\n' ',' | sed 's/,$//')
COMMITS=$(gh pr view "$PR_ID" --json commits -q '.commits.totalCount')
FILES_CHANGED=$(gh pr view "$PR_ID" --json files -q '.files | length')

# Ensure COMMITS is a number
if ! [[ "$COMMITS" =~ ^[0-9]+$ ]]; then
  echo "⚠️ Warning: Unable to determine the number of commits in PR. Defaulting to 1."
  COMMITS=1
fi

# Check if PR is already closed or merged
if [ "$PR_STATE" == "CLOSED" ]; then
  echo "❌ Error: Pull request #$PR_ID is closed and cannot be merged."
  exit 1
elif [ "$PR_STATE" == "MERGED" ]; then
  echo "❌ Error: Pull request #$PR_ID is already merged."
  exit 1
fi

# Check if the PR is already approved
if [ -n "$APPROVED_BY" ]; then
  echo "✅ PR #$PR_ID is already approved by: $APPROVED_BY"
else
  read -p "PR #$PR_ID is not approved yet. Do you want to approve it? (y/n): " APPROVE_CONFIRM
  if [[ "$APPROVE_CONFIRM" != "y" && "$APPROVE_CONFIRM" != "Y" ]]; then
    echo "❌ Operation canceled by the user."
    exit 1
  fi

  echo "⚠️ PR #$PR_ID is not approved yet. Approving now..."
  gh pr review "$PR_ID" --approve
  if [ $? -eq 0 ]; then
    echo "✅ Successfully approved PR #$PR_ID."
  else
    echo "❌ Error while approving the pull request."
    exit 1
  fi
fi

# Fetch the latest changes and check for conflicts
echo "⏳ Fetching the latest changes..."
git fetch origin

# Attempt to merge the PR branch into the current branch to check for conflicts
echo "⚠️ Checking for merge conflicts..."
git merge --no-commit --no-ff "origin/$BRANCH" &> /dev/null

# Check if the merge was successful
if [ $? -ne 0 ]; then
  echo "❌ Error: There are merge conflicts. Please resolve them before proceeding."
  git merge --abort 2>/dev/null  # Only attempt to abort if a merge was started
  exit 1
else
  git merge --abort 2>/dev/null  # Abort the merge if no conflicts
  echo "✅ No merge conflicts detected."
fi

# Check the number of commits in the PR
if [ "$COMMITS" -gt 1 ]; then
  read -p "PR contains $COMMITS commits. Do you want to squash them before merging? (y/n): " SQUASH_CONFIRM
  if [[ "$SQUASH_CONFIRM" != "y" && "$SQUASH_CONFIRM" != "Y" ]]; then
    echo "❌ Operation canceled by the user."
    exit 1
  fi
  SQUASH_OPTION="--squash"
else
  SQUASH_OPTION=""
fi

# Confirmation before merging
echo "⚠️ You are about to merge PR #$PR_ID and delete the branch '$BRANCH'."
read -p "Do you want to proceed? (y/n): " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "❌ Operation canceled by the user."
  exit 1
fi

# Merge the pull request
echo "⏳ Merging pull request #$PR_ID..."
gh pr merge "$PR_ID" $SQUASH_OPTION --delete-branch

if [ $? -eq 0 ]; then
  echo "✅ PR #$PR_ID has been successfully merged, and branch '$BRANCH' has been deleted."
else
  echo "❌ Error occurred while merging the pull request."
  exit 1
fi