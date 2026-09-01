#!/usr/bin/env bash
# vim:sw=2:ts=2:sts=2:et
while getopts a:n:u: flag
do
  case "${flag}" in
    a) owner=${OPTARG};;
    n) name=${OPTARG};;
    u) url=${OPTARG};;
    *) echo "Invalid flag: ${flag}"; exit 1;;
  esac
done

# Resolve the documentation flavor from the repository owner. NGINX organizations
# get the NGINX community/documentation resources, everybody else gets the F5 ones.
case "$(echo "$owner" | tr '[:upper:]' '[:lower:]')" in
  nginx|nginxinc) flavor="NGINX"; discarded_flavor="F5";;
  *)              flavor="F5";    discarded_flavor="NGINX";;
esac

echo "Owner: $owner";
echo "Repository Name: $name";
echo "Repository URL: $url";
echo "Flavor: $flavor";

echo "Renaming repository..."

original_owner="{{REPOSITORY_OWNER}}"
original_name="{{REPOSITORY_NAME}}"
original_url="{{REPOSITORY_URL}}"
for filename in $(git ls-files)
do
  sed -i "s/$original_owner/$owner/g" "$filename"
  sed -i "s/$original_name/$name/g" "$filename"
  sed -i "s/$original_url/$url/g" "$filename"
  # Delete the discarded flavor's blocks wholesale, then unwrap the blocks we keep
  # by dropping only their marker lines. Markers are written as HTML comments in
  # Markdown files and as `#` comments in YAML files; both forms match here.
  sed -i "/BEGIN FLAVOR:$discarded_flavor/,/END FLAVOR:$discarded_flavor/d" "$filename"
  sed -i "/BEGIN FLAVOR:$flavor/d;/END FLAVOR:$flavor/d" "$filename"
  echo "Renamed $filename"
done

# These commands run only once on GitHub Actions!
echo "Removing template specific data..."
# Remove OSSF attestations and F5 specific GitHub Actions workflows
rm -f .github/scorecard.yml
if [[ "$GITHUB_REPOSITORY_OWNER" != "devcentral" && "$GITHUB_REPOSITORY_OWNER" != "f5" && "$GITHUB_REPOSITORY_OWNER" != "f5devcentral" && "$GITHUB_REPOSITORY_OWNER" != "f5networks" && "$GITHUB_REPOSITORY_OWNER" != "nginx" && "$GITHUB_REPOSITORY_OWNER" != "nginxinc" ]]; then
  rm -f .github/workflows/f5_cla.yml
fi
# Replace project issue forms with the templated issue forms (filled by sed above)
mv -f .github/ISSUE_TEMPLATE/bug_report.yml.template .github/ISSUE_TEMPLATE/bug_report.yml
mv -f .github/ISSUE_TEMPLATE/feature_request.yml.template .github/ISSUE_TEMPLATE/feature_request.yml
# Remove the template instructions from the README and the template's CHANGELOG
sed -i '1,/^---$/ { /^$/d; d }' README.md
sed -i '1,/^---$/ { /^$/d; d }' CHANGELOG.md
# Remove Renovatebot and activate Dependabot
rm -f .github/renovate.json
mv .github/dependabot.yml.template .github/dependabot.yml
# Remove this script and the GitHub Action workflow using this script
rm -f .github/workflows/rename_template.yml
rm -rf .github/workflows/scripts
