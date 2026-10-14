with Zlib;

--  Archive writers that preserve selected directory entries as well as files.
package Files.Archive_Writing is
   --  Check that an archive catalogue can be extracted without exhausting the
   --  destination volume or crossing the application's structural limits.
   --  Unknown volume figures still receive conservative absolute and expansion
   --  bounds.  Known figures retain headroom for the running system.
   --
   --  @param Entries Catalogue returned by Zlib before extraction.
   --  @param Free_Bytes Bytes currently available on the destination volume.
   --  @param Free_Bytes_Known True when Free_Bytes is authoritative.
   --  @param Free_Inodes Inodes currently available on the destination volume.
   --  @param Free_Inodes_Known True when Free_Inodes is authoritative.
   --  @return True only when every resource bound is satisfied.
   function Extraction_Is_Within_Limits
     (Entries            : Zlib.Archive_Entry_Array;
      Free_Bytes         : Long_Long_Integer;
      Free_Bytes_Known   : Boolean;
      Free_Inodes        : Long_Long_Integer;
      Free_Inodes_Known  : Boolean) return Boolean;

   --  @param Input_Paths Source files and directories, without following links.
   --  @param Output_Path Staged output archive, published by the caller.
   --  @param Entry_Names Distinct relative names parallel to Input_Paths.
   --  @param Status Ok only when every source has been included.
   procedure ZIP_Files
     (Input_Paths : Zlib.Text_Array;
      Output_Path : String;
      Entry_Names : Zlib.Text_Array;
      Status : out Zlib.Status_Code);
end Files.Archive_Writing;
