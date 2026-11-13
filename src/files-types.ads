with Ada.Calendar;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

with Guikit.Draw;
with Hostkit.Metadata;

--  Shared value types used across the files model, commands, and rendering.
package Files.Types is
   --  The time a record holds when it has none: a date no file carries, so
   --  it is never mistaken for one (the matching Available flag says so too).
   Unknown_Time : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);

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

   --  Byte buffer type shared with the renderer-agnostic draw model. Re-exported
   --  from Guikit.Draw so the draw model stays domain-free while application
   --  code keeps using Files.Types.Byte_Vectors unchanged.
   package Byte_Vectors renames Guikit.Draw.Byte_Vectors;

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

   --  A path's last component read from its text alone
   --  (Hostkit.Path_Text.Leaf), for a unit that reads no disk: GNAT's Windows
   --  Ada.Directories.Simple_Name refuses a component past 256 characters.
   --
   --  @param Path A path.
   --  @return Its last component, indexed from 1, or "" for a root.
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

   --  Read a decimal id: ASCII digits only, at most 4294967295. Never raises.
   --
   --  @param Text Candidate decimal id.
   --  @return Whether Text is a valid id, and the id when it is.
   function Parse_Account_Id (Text : String) return Parsed_Account_Id
     renames Hostkit.Metadata.Parse_Account_Id;

   type View_Mode is
     (Small_Icons,
      Large_Icons,
      Details);

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

   --  Selectable detail-view columns. The name column is always shown and
   --  cannot be hidden; the remaining columns are individually toggleable and,
   --  when visible, laid out left to right in this declaration order.
   type Detail_Column is
     (Name_Column,
      Modified_Column,
      Size_Column,
      Filetype_Column,
      Created_Column,
      Permissions_Column);

   --  Toggleable detail columns, i.e. every column except the mandatory name.
   subtype Optional_Detail_Column is
     Detail_Column range Modified_Column .. Permissions_Column;

   --  Per-column visibility flags for the detail view.
   type Detail_Column_Visibility is array (Detail_Column) of Boolean;

   --  Per-column pixel widths for the detail view. A width of zero means the
   --  layout derives a proportional default for that column.
   type Detail_Column_Widths is array (Detail_Column) of Natural;

   --  Default detail-column visibility: name, modified, size, and type are
   --  shown; created and permissions stay hidden until enabled.
   Default_Detail_Column_Visibility : constant Detail_Column_Visibility :=
     [Name_Column        => True,
      Modified_Column    => True,
      Size_Column        => True,
      Filetype_Column    => True,
      Created_Column     => False,
      Permissions_Column => False];

   --  Default per-column widths: zero for every column so the layout derives
   --  proportional defaults until a width is customized.
   Default_Detail_Column_Widths : constant Detail_Column_Widths := [others => 0];

   --  Smallest width a customized detail column may occupy, in reference
   --  units (pixels at the reference line height; scaled with it when drawn).
   Minimum_Detail_Column_Width : constant := 48;

   --  Number of detail columns; the length of a full column-order permutation.
   Detail_Column_Count : constant := Detail_Column'Pos (Detail_Column'Last) + 1;

   --  One-based slot index into a detail column-order permutation.
   subtype Detail_Column_Index is Positive range 1 .. Detail_Column_Count;

   --  A permutation of every detail column giving their left-to-right order in
   --  the detail view. The mandatory name column always occupies the first
   --  slot; the optional columns are ordered among themselves after it. Hidden
   --  columns still occupy a slot but do not render, so re-showing one restores
   --  it to its ordered position.
   type Detail_Column_Order is array (Detail_Column_Index) of Detail_Column;

   --  Default column order: the declaration (enum) order, name first.
   Default_Detail_Column_Order : constant Detail_Column_Order :=
     [1 => Name_Column,
      2 => Modified_Column,
      3 => Size_Column,
      4 => Filetype_Column,
      5 => Created_Column,
      6 => Permissions_Column];

   --  Return Order with Column moved to occupy slot To_Index (one-based) in the
   --  resulting left-to-right order. The mandatory name column never moves and
   --  always keeps the first slot: a request to move name, or to target the
   --  first slot, is clamped so name stays first. Moving a column to the slot it
   --  already occupies returns Order unchanged. The result is always a
   --  permutation of Order.
   --
   --  @param Order Current column-order permutation.
   --  @param Column Column to move.
   --  @param To_Index Target one-based slot for Column in the result.
   --  @return Updated column-order permutation.
   function Move_Column
     (Order    : Detail_Column_Order;
      Column   : Detail_Column;
      To_Index : Detail_Column_Index)
      return Detail_Column_Order;

   --  A fixed color label (tag) assignable to any item. No_Label means the item
   --  carries no tag; the remaining values name the seven selectable swatch
   --  colors in their canonical display order.
   type Color_Label is
     (No_Label,
      Red,
      Orange,
      Yellow,
      Green,
      Blue,
      Purple,
      Gray);

   --  The seven real (assignable) label colors, excluding the No_Label clear
   --  state. Used to iterate the color swatches and label bands in order.
   subtype Real_Color_Label is Color_Label range Red .. Gray;

   --  Which right-click context menu is open: on an item, on the empty area
   --  of a folder, on a column header -- or none.
   type Context_Menu_Target is
     (Context_Menu_None,
      Context_Menu_Item,
      Context_Menu_Empty,
      Context_Menu_Header);

   --  The label picker's swatch count: one per real color, then the clear
   --  swatch.
   Swatch_Count : constant :=
     Real_Color_Label'Pos (Real_Color_Label'Last) - Real_Color_Label'Pos (Real_Color_Label'First) + 2;

   --  The label picker's clear (No_Label) swatch: the last one.
   Clear_Swatch : constant := Swatch_Count;

   --  The label picker's swatches in order: one per real color, then the
   --  clear swatch (No_Label). The one mapping the renderer, the hit-test
   --  and the model's keyboard highlight share.
   --
   --  @param Index One-based swatch index.
   --  @return The label that swatch sets.
   function Label_For_Swatch (Index : Positive) return Color_Label is
     (if Index <= Real_Color_Label'Pos (Real_Color_Label'Last) then Color_Label'Val (Index) else No_Label);

   --  Detail-view row grouping mode. When it is not No_Grouping the detail list
   --  gains non-selectable group header rows composed with the active sort.
   type Group_Mode is
     (No_Grouping,
      Group_By_Type,
      Group_By_Modified,
      Group_By_Size,
      Group_By_Label);

   type Item_Kind is
     (Directory_Item,
      Regular_File_Item,
      Symlink_Item,
      Executable_Item,
      Unknown_Item,
      Other_Item);

   type Focus_Target is
     (Focus_None,
      Focus_Path_Input,
      Focus_Filter_Input,
      Focus_Rename_Input,
      Focus_Command_Palette,
      Focus_Settings_Input,
      Focus_Ownership_Input);

   --  Scope the shared filter-bar query applies to. Filter_Here live-filters the
   --  current directory by name (the default), Search_Names replaces the view
   --  with a recursive name search of the subtree, and Search_Contents replaces
   --  it with a recursive content (grep) search. All three reuse one query text.
   type Search_Scope is
     (Filter_Here,
      Search_Names,
      Search_Contents);

   --  Return the search scope reached by cycling one step forward, wrapping from
   --  Search_Contents back to Filter_Here.
   --
   --  @param Scope Current search scope.
   --  @return Next search scope in the cycle.
   function Next_Scope (Scope : Search_Scope) return Search_Scope;

   --  Return Text converted to lower case using simple Ada character folding
   --  plus common UTF-8 Latin-1 uppercase letters.
   --
   --  @param Text Text to normalize.
   --  @return Lower-case version of Text.
   function To_Lower (Text : String) return String;

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

   --  Raw cut back to its last whole UTF-8 character: a multibyte sequence a
   --  bounded read cut short is dropped. Anything else is left as it is.
   --
   --  @param Raw Bytes read from the start of a file, possibly cut short.
   --  @return Raw without a trailing incomplete character.
   function Trim_To_Character (Raw : String) return String;

   --  Return a case-insensitive, accent-folded sort key for Text: an
   --  ASCII-lowercased copy in which the accented Latin letters are reduced to
   --  their base letter (a-with-umlaut becomes a, sharp-s becomes ss, and so
   --  on). Ordering two names by String "<" on these keys sorts an accented name
   --  next to its base letter, the way a reader expects, instead of by raw UTF-8
   --  byte -- where every non-ASCII name lands after all of a..z. Non-Latin
   --  scripts keep their codepoint order. Deterministic and self-contained: no
   --  locale data is consulted, so the order never depends on the environment.
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
