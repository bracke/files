--  How long a leaf name a filesystem stores, and how to cut one down to fit.
--
--  Pure rules, with no filesystem access: the caller says which rules apply
--  (Hostkit.Fs.Uses_Dos_Filename_Rules for the destination directory), so
--  every host checks every rule set alike and the tests run them on Linux.
package Files.Leaf_Names is

   --  The longest leaf name a filesystem stores: 255 UTF-16 units where DOS
   --  rules apply (NTFS, FAT, exFAT), 255 bytes elsewhere.
   Max_Length : constant := 255;

   --  The length of Name as a filesystem under the given rules measures it.
   --
   --  @param Name A leaf name, UTF-8 encoded.
   --  @param Dos_Rules Whether the destination keeps names in UTF-16 (NTFS,
   --    FAT, exFAT) rather than as bytes.
   --  @return UTF-16 units under DOS rules -- bytes when Name is not valid
   --    UTF-8, which never undercounts -- and bytes otherwise.
   function Length_Under
     (Name      : String;
      Dos_Rules : Boolean)
      return Natural;

   --  Whether Name is longer than a filesystem under the given rules stores.
   --
   --  @param Name A leaf name, UTF-8 encoded.
   --  @param Dos_Rules Whether DOS (UTF-16) rules apply at the destination.
   --  @return True when Length_Under (Name, Dos_Rules) exceeds Max_Length.
   function Too_Long_Under
     (Name      : String;
      Dos_Rules : Boolean)
      return Boolean is
     (Length_Under (Name, Dos_Rules) > Max_Length);

   --  Head cut down at a whole UTF-8 character, as little as needed, with
   --  Tail kept whole after it, so the result measures at most Room.
   --
   --  @param Head The part that may be shortened (a stem).
   --  @param Tail The part kept whole (a counter and an extension).
   --  @param Room The most the result may measure (Length_Under).
   --  @param Dos_Rules Whether DOS (UTF-16) rules measure the result.
   --  @return Head's longest prefix that fits, then Tail; just Tail when no
   --    prefix fits, which then may still not.
   function Cut
     (Head      : String;
      Tail      : String;
      Room      : Natural;
      Dos_Rules : Boolean := False)
      return String;

   --  Name with Insert placed before its extension, its stem cut down as
   --  Cut cuts so the whole measures at most Room. The extension -- from the
   --  last dot, unless the name starts with that dot or it is longer than 32
   --  bytes -- is kept whole; a name that fits as it is comes back unchanged
   --  but for Insert.
   --
   --  @param Name A leaf name, UTF-8 encoded.
   --  @param Room The most the result may measure (Length_Under).
   --  @param Dos_Rules Whether DOS (UTF-16) rules measure the result.
   --  @param Insert Text placed between the stem and the extension.
   --  @return The fitted name.
   function Fit
     (Name      : String;
      Room      : Natural;
      Dos_Rules : Boolean := False;
      Insert    : String := "")
      return String;

end Files.Leaf_Names;
