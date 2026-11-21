--  Case: lowering and upper-casing ASCII tokens, folding text a person reads
--  for a case-insensitive match, and the sort key every name list orders by.
package Files.Text_Case is

   --  Text with its ASCII letters lower-cased and every other byte kept, so
   --  UTF-8 passes through untouched: for what is ASCII by definition --
   --  tokens, keys, MIME types, extensions. Text a person reads or types
   --  (names, labels) folds with Fold_Case, which knows every script.
   --
   --  @param Text Text to lower-case.
   --  @return Text with A .. Z lower-cased.
   function To_Lower_Ascii (Text : String) return String;

   --  Text in lower case by Unicode's simple mapping, every script alike
   --  ("ДОК" is "док"), with no normalization and no data to load, so it
   --  answers the same everywhere; text that is not valid UTF-8 is lowered
   --  in ASCII only.
   --
   --  @param Text Text to lower.
   --  @return Lowered text.
   function To_Lower_Unicode (Text : String) return String;

   --  Text with its ASCII letters upper-cased and every other byte kept, the
   --  counterpart of To_Lower_Ascii: Ada.Characters.Handling.To_Upper would
   --  map Latin-1 bytes too, mangling a UTF-8 lead byte.
   --
   --  @param Text Text to upper-case.
   --  @return Text with a .. z upper-cased.
   function To_Upper_Ascii (Text : String) return String;

   --  @param Item Character to upper-case.
   --  @return Item upper-cased when it is an ASCII letter a .. z, else Item.
   function To_Upper_Ascii (Item : Character) return Character is
     (if Item in 'a' .. 'z' then Character'Val (Character'Pos (Item) - 32) else Item);

   --  Text folded for a case-insensitive match: every script's letters, not
   --  only Latin-1 (Привет, Łódź, Ελλάδα), and one Unicode form, so a name
   --  stored decomposed (é as e and a combining accent, as older Macs write
   --  it) matches the composed é a user types. The result is for comparing
   --  only -- its length can differ from Text's. Bytes that are not UTF-8
   --  are kept as they are, and the well-formed text around them is folded
   --  all the same: one stray byte (a read cut mid-character) must not cost
   --  the rest its folding.
   --
   --  @param Text Text to fold.
   --  @return Folded text.
   function Fold_Case (Text : String) return String;

   --  Whether Text (Files.Text_Encoding.Searchable_Text) is text, not binary
   --  (Files.Text_Encoding.Looks_Binary), and
   --  contains Folded_Query (a query already folded with Fold_Case),
   --  ignoring case: content search's match, with the query folded once
   --  per search rather than once per file.
   --
   --  @param Text A file's first bytes as Files.Text_Encoding.Searchable_Text
   --    gives them.
   --  @param Folded_Query Fold_Case of the text looked for; "" matches nothing.
   --  @return True for a text match.
   function Text_Contains (Text : String; Folded_Query : String) return Boolean;

   --  Return a case-insensitive, accent-folded sort key for Text, the one key
   --  every name list sorts by (listings, the application picker). Every
   --  script's letters fold to lower case (Ada's own Unicode tables), and an
   --  accent or other combining mark is dropped, whether it is stored as a
   --  mark of its own (decomposed, as macOS and many SMB servers write names)
   --  or within a precomposed letter: the Latin, Greek and Cyrillic letters
   --  and the voiced kana fold to their base letter (a-with-umlaut becomes a,
   --  sharp-s becomes ss, Cyrillic short i becomes i, ga becomes ka), and
   --  decomposed Hangul jamo compose into their syllable. So a name sorts the
   --  same however it is stored, and next to its base letter instead of by
   --  raw UTF-8 byte -- where every non-ASCII name lands after all of a..z.
   --  Deterministic and self-contained: no locale or normalization data is
   --  consulted, so the order never depends on the environment. Bytes that
   --  are not UTF-8 are kept as they are.
   --
   --  @param Text Text to build a sort key for.
   --  @return Folded key; compare keys with String "<".
   function Fold_For_Sort (Text : String) return String;

   --  Return whether Needle occurs in Haystack after case folding.
   --
   --  @param Haystack Text to search.
   --  @param Needle Text to find.
   --  @return True when Needle occurs in Haystack case-insensitively.
   function Contains_Case_Insensitive
     (Haystack : String;
      Needle   : String)
      return Boolean;
end Files.Text_Case;
