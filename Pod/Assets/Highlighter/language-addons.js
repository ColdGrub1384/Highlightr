//
//  language-addons.js
//  Pyto
//
//  Created by Emma Labbe on 18-09-26.
//  Copyright © 2026 Emma Labbé. All rights reserved.
//

/*! `cython` grammar compiled for Highlight.js 11.12.0 */
(function () {
  var hljsGrammar = (function () {
    "use strict";

    function cython(hljs) {
      const python = hljs.getLanguage("python");

      if (!python) {
        throw new Error("Requires Python grammar");
      }

      const def = python.rawDefinition || python;
      const keywords = def.keywords || {};

      const extraKeywords = [
        "api",
        "by",
        "cdef",
        "cimport",
        "cpdef",
        "ctypedef",
        "DEF",
        "ELIF",
        "ELSE",
        "IF",
        "include",
        "inline",
        "gil",
        "nogil",
        "public",
        "readonly",
        "extern",
      ];

      const extraTypes = [
        "bint",
        "char",
        "double",
        "float",
        "int",
        "long",
        "object",
        "short",
        "void",
      ];

      return {
        ...def,
        name: "Cython",
        aliases: ["pyx", "pyrex"],
        keywords: {
          $pattern: /[A-Za-z]\w+|__\w+__/,
          keyword: Array.from(
            new Set((keywords.keyword || []).concat(extraKeywords))
          ),
          built_in: Array.from(new Set(keywords.built_in || [])),
          literal: Array.from(new Set(keywords.literal || [])),
          type: Array.from(
            new Set((keywords.type || []).concat(extraTypes))
          ),
        },
        contains: def.contains.concat([
          {
            beginKeywords: "cdef cpdef cimport ctypedef DEF IF ELIF ELSE",
            relevance: 0,
          },
          {
            className: "meta",
            begin: /^(?:DEF|IF|ELIF|ELSE)\b/,
            end: /$/,
            contains: [hljs.HASH_COMMENT_MODE],
          },
        ]),
      };
    }

    return cython;
  })();

  hljs.registerLanguage("cython", hljsGrammar);
})();

/*! `meson` grammar compiled for Highlight.js 11.12.0 */
(function () {
  var hljsGrammar = (function () {
    "use strict";

    function meson(hljs) {
      return {
        name: "Meson",
        aliases: ["meson.build"],
        keywords: {
          keyword:
            "if else endif foreach endforeach break continue true false",
          built_in:
            "project executable library shared_library static_library dependency find_program configuration_data configure_file subdir option get_option import message warning error include_directories add_global_arguments add_project_arguments",
        },
        contains: [
          hljs.HASH_COMMENT_MODE,
          hljs.QUOTE_STRING_MODE,
          hljs.APOS_STRING_MODE,
          hljs.NUMBER_MODE,
        ],
      };
    }

    return meson;
  })();

  hljs.registerLanguage("meson", hljsGrammar);
})();
