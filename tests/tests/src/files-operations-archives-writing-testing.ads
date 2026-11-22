--  What the suite reaches of Files.Operations.Archives.Writing that is not part of its interface.
package Files.Operations.Archives.Writing.Testing is

   --  Whether every entry name in Entries can be extracted without escaping
   --  the destination or overwriting another entry (First_Unextractable).
   --
   --  @param Entries Catalogue returned by Zlib before extraction.
   --  @param Dos_Rules Whether each name segment must be one Windows can
   --    store (a FAT, exFAT or NTFS destination): no device names such as nul
   --    or aux.c, no trailing dot or space, none of \ : < > " | ? *.
   --  @param Case_Insensitive Whether two files whose names differ only in
   --    case would land on the same file there, and so count as duplicates.
   --  @return True when no name is unsafe, unstorable or a duplicate.
   function Names_Are_Extractable
     (Entries          : Zlib.Archive_Entry_Array;
      Dos_Rules        : Boolean;
      Case_Insensitive : Boolean) return Boolean;

   --  The first entry of Entries whose name cannot be extracted, as the
   --  archive lists it, or "" when every one can. A name is read as the path
   --  zlib extracts it to (Zlib.Entry_Path_Name: '\' separates in a name
   --  written by an old Windows tool) and must stay below the destination
   --  (Zlib.Safe_Entry_Path); a ':' is a name's own character unless the
   --  host or a DOS-rules destination says otherwise.
   --
   --  @param Entries Catalogue returned by Zlib before extraction.
   --  @param Dos_Rules As Names_Are_Extractable.
   --  @param Case_Insensitive As Names_Are_Extractable.
   --  @return The refused entry's name, or "".
   function First_Unextractable
     (Entries          : Zlib.Archive_Entry_Array;
      Dos_Rules        : Boolean;
      Case_Insensitive : Boolean) return String;

end Files.Operations.Archives.Writing.Testing;
