// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.

#ifndef COUCHJS_HELP_H
#define COUCHJS_HELP_H

#include <libgen.h>

static const char VERSION_TEMPLATE[] =
    "%s - %s\n"
    "\n"
    "Licensed under the Apache License, Version 2.0 (the \"License\"); you may "
        "not use\n"
    "this file except in compliance with the License. You may obtain a copy of"
        "the\n"
    "License at\n"
    "\n"
    "  http://www.apache.org/licenses/LICENSE-2.0\n"
    "\n"
    "Unless required by applicable law or agreed to in writing, software "
        "distributed\n"
    "under the License is distributed on an \"AS IS\" BASIS, WITHOUT "
        "WARRANTIES OR\n"
    "CONDITIONS OF ANY KIND, either express or implied. See the License "
        "for the\n"
    "specific language governing permissions and limitations under the "
        "License.\n";

static const char USAGE_TEMPLATE[] =
    "Usage: %s [FILE]\n"
    "\n"
    "The %s command runs the %s JavaScript interpreter.\n"
    "\n"
    "The exit status is 0 for success or 1 for failure.\n"
    "\n"
    "Options:\n"
    "\n"
    "  -h          display a short help message and exit\n"
    "  -V          display version information and exit\n"
    "  -H          enable %s cURL bindings (only avaiable\n"
    "              if package was built with cURL available)\n"
    "  -S SIZE     specify that the interpreter should set the\n"
    "              stack quota for JS contexts to SIZE bytes\n"
    "  -u FILE     path to a .uri file containing the address\n"
    "              (or addresses) of one or more servers\n"
    "\n"
    "Report bugs at <%s>.\n";

#define BASENAME basename((char*)argv[0])

#define couch_version(basename)  \
    fprintf(                     \
            stdout,              \
            VERSION_TEMPLATE,    \
            basename,            \
            "1.3.0")

#define DISPLAY_VERSION couch_version(BASENAME)


#define couch_usage(basename) \
    fprintf(                                    \
            stdout,                             \
            USAGE_TEMPLATE,                     \
            basename,                           \
            basename,                           \
            "refuge",                           \
            basename,                           \
            "https://github.com/refuge/couch_core/issues")

#define DISPLAY_USAGE couch_usage(BASENAME)

#endif // Included help.h
