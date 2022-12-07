# What's New

Nothing to see here.

# Usage 
<!-- start usage -->
```yaml

name: Get Application Token
on:
  workflow_dispatch:
jobs:
  update:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - name: Get GitHub Application Token
        id: get-github-app-token
        uses: acceleratelearning/action-get-application-token@v1
        with:
          github-app-id: ${{ secrets.COMPOSER_APP_ID }}
          github-app-key: ${{ secrets.COMPOSER_APP_KEY }}

      - name: Test Token
        run: |
          curl -v -H "Accept: application/vnd.github+json" -H "Authorization: token $INPUT_GITHUB_APP_TOKEN" https://api.github.com/repos/acceleratelearning/stemscopes-v4-lib-grpc-proto/zipball/ea2fdb194eeed6c3e7fdbbc1cb4246b11d805a99
        env:
          INPUT_GITHUB_APP_TOKEN: ${{ steps.get-github-app-token.outputs.github-app-token }}
```
<!-- end usage -->