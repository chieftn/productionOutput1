def package_name:
  type == "string"
  and length > 0
  and length <= 214
  and . != "node_modules"
  and . != "favicon.ico"
  and test("\\A(?:@[a-z0-9][a-z0-9._~-]*/)?[a-z0-9][a-z0-9._~-]*\\z");

def semver:
  type == "string"
  and test("\\A(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(\\.(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?\\z");

length == 1
and (.[0] |
  type == "object"
  and (.name | package_name)
  and (.version | semver)
  and .private == true
  and (has("dependencies") | not)
  and (has("devDependencies") | not)
  and (has("scripts") | not)
)
