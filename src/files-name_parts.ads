--  The parts of a leaf name and a path's last component: stem, extension,
--  and the stem a new name is built from. Text only; nothing reads the disk.
package Files.Name_Parts is

   --  Where a leaf name's extension starts: its last '.', unless that is the
   --  first character (".bashrc" is all name) or the last ("draft." has no
   --  extension). The one rule for splitting a name into stem and extension.
   --
   --  @param Name A leaf name.
   --  @return The extension's dot, or 0 when the name has none.
   function Extension_Start (Name : String) return Natural;

   --  Whether the '.' at Index in Name may start an extension by
   --  Extension_Start's rule: it is neither the first character nor the
   --  last. For a caller that weighs every dot, not only the last.
   --
   --  @param Name A leaf name.
   --  @param Index Position of a '.' in Name.
   --  @return True when an extension may start there.
   function May_Start_Extension (Name : String; Index : Positive) return Boolean is
     (Index > Name'First and then Index < Name'Last);

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
end Files.Name_Parts;
