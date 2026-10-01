with Zlib;

--  Archive writers that preserve selected directory entries as well as files.
package Files.Archive_Writing is
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
