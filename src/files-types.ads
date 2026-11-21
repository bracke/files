with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Shared_Bytes;
with Hostkit.Metadata;

--  Shared value types used across the files model, commands, and rendering.
package Files.Types is
   --  The time a record holds when it has none: a date no file carries, so
   --  it is never mistaken for one (the matching Available flag says so too).
   Unknown_Time : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);

   --  How many bytes a streaming read or copy moves per call: the size of
   --  the one buffer every such loop reuses.
   IO_Chunk_Bytes : constant := 64 * 1024;

   subtype UString is Ada.Strings.Unbounded.Unbounded_String;

   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => UString,
      "="          => Ada.Strings.Unbounded."=");

   --  What became of an item whose labels, favorites and recent entries
   --  should follow it: it now lives elsewhere, or it is gone for good.
   type Path_Move_Kind is (Moved, Removed);

   --  One rename, move or removal. To is the new full path of a Moved item
   --  and empty for a Removed one.
   type Path_Move is record
      From : UString;
      To   : UString;
      Kind : Path_Move_Kind := Moved;
   end record;

   package Path_Move_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Path_Move);

   --  Byte buffer type shared with the renderer-agnostic draw model, which
   --  renames the same Guikit.Shared_Bytes instance: application code keeps
   --  using Files.Types.Byte_Vectors without depending on the draw model.
   package Byte_Vectors renames Guikit.Shared_Bytes.Byte_Vectors;

   --  A numeric user or group id. Re-exported from Hostkit.Metadata, which
   --  reads and sets them: uid_t and gid_t are unsigned 32-bit, and ids from
   --  2**31 up are real ones (an idmapped mount, NFS's nobody at 4294967294),
   --  so a Natural cannot hold them. `use type Files.Types.Account_Id` makes
   --  its operators visible.
   subtype Account_Id is Hostkit.Metadata.Account_Id;
   subtype Parsed_Account_Id is Hostkit.Metadata.Parsed_Account_Id;

   --  The id in decimal, without a leading blank: "4294967294".
   --
   --  @param Id Account id to print.
   --  @return Its decimal digits.
   function Account_Image (Id : Account_Id) return String
     renames Hostkit.Metadata.Account_Image;

   --  Where a leaf name's extension starts: its last '.', unless that is the
   --  first character (".bashrc" is all name) or the last ("draft." has no
   --  extension). The one rule for splitting a name into stem and extension.
   --
   --  @param Name A leaf name.
   --  @return The extension's dot, or 0 when the name has none.
   function Extension_Start (Name : String) return Natural;

   --  A leaf name before its extension (Extension_Start): "notes" of
   --  "notes.txt", all of ".bashrc".
   --
   --  @param Name A leaf name.
   --  @return The stem.
   function Stem_Of (Name : String) return String;

   --  A leaf name's extension without its dot (Extension_Start): "txt" of
   --  "notes.txt", "" for ".bashrc" or "draft.".
   --
   --  @param Name A leaf name.
   --  @return The extension, or "".
   function Extension_Of (Name : String) return String;

   --  Name's stem as a new name is built from it (a copy, a link, an
   --  archive, a numbered paste): a file's and a package's Stem_Of, and all
   --  of a plain folder's name, whose dots are part of it ("v1.2" is
   --  "v1.2 (copy)", not "v1 (copy).2").
   --
   --  @param Name A leaf name.
   --  @param Is_Directory Whether it names a folder.
   --  @return The stem.
   function Name_Stem (Name : String; Is_Directory : Boolean) return String;

   --  Name's extension, by the rule Name_Stem splits by: "" for a plain folder.
   --
   --  @param Name A leaf name.
   --  @param Is_Directory Whether it names a folder.
   --  @return The extension without its dot, or "".
   function Name_Extension (Name : String; Is_Directory : Boolean) return String;

   --  Path's last component read from its text alone (Hostkit.Path_Text.Leaf),
   --  for every unit, whether or not it reads the disk. Ada.Directories.Simple_Name
   --  is not to be used on a path: GNAT's Windows runtime rejects a component
   --  longer than 256 characters, which the filesystem then refuses with a
   --  cause of its own ("too long"), not as an invalid name, and reads
   --  "\\server\share" as a folder.
   --
   --  @param Path A path.
   --  @return Its last component without trailing separators, indexed from 1,
   --    or "" for a root or an empty path.
   function Leaf_Of (Path : String) return String;

   --  A count in decimal, without the leading blank Natural'Image gives it.
   --
   --  @param Value Count to print.
   --  @return Its decimal digits.
   function Natural_Text (Value : Natural) return String;

   --  Text without the spaces, tabs and carriage returns around it, as a
   --  line of a settings or desktop-entry file is read.
   --
   --  @param Text A line or a field of one.
   --  @return Text trimmed.
   function Trim_Blanks (Text : String) return String;

   --  The entries of a path list such as XDG_DATA_DIRS or PATH, split on
   --  Separator: ':' on POSIX hosts, ';' on Windows, where ':' is part of a
   --  drive letter. Empty entries are kept, so a caller can skip them as it
   --  does any unusable entry.
   --
   --  @param List The list's text.
   --  @param Separator The host's path-list separator.
   --  @return The entries in order.
   function Split_Path_List (List : String; Separator : Character) return String_Vectors.Vector;

   --  Read a decimal id: ASCII digits only, at most 4294967295. Never raises.
   --
   --  @param Text Candidate decimal id.
   --  @return Whether Text is a valid id, and the id when it is.
   function Parse_Account_Id (Text : String) return Parsed_Account_Id
     renames Hostkit.Metadata.Parse_Account_Id;

   --  The field items are sorted by: the one enumeration the model, the
   --  settings file and the sort commands share. This declaration order is
   --  the sort menu's row order. The settings file stores each field as its
   --  own token (Files.Settings owns that mapping), never as a position.
   type Sort_Field is
     (Sort_Name,
      Sort_Size,
      Sort_Type,
      Sort_Created,
      Sort_Changed);

   --  The listing policy a directory load applies: whether hidden entries are
   --  listed, and the order the listed items are sorted into. A load reads only
   --  these from the settings for filtering and ordering, so a caller with its
   --  own policy (emptying the Trash lists hidden payloads too) states it here
   --  instead of editing a copy of the whole settings.
   type Listing_Options is record
      Show_Hidden    : Boolean := False;
      Sort_Field     : Files.Types.Sort_Field := Sort_Name;
      Sort_Ascending : Boolean := True;
   end record;

   type Item_Kind is
     (Directory_Item,
      Regular_File_Item,
      Symlink_Item,
      Executable_Item,
      Unknown_Item,
      Other_Item);

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

   --  @param Text Text to inspect.
   --  @param Prefix Bytes Text must begin with.
   --  @return True when Text begins with exactly Prefix.
   function Starts_With (Text : String; Prefix : String) return Boolean is
     (Text'Length >= Prefix'Length
      and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

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
end Files.Types;
