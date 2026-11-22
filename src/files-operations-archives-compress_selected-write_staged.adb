separate (Files.Operations.Archives.Compress_Selected)
function Write_Staged (Staged : String) return Zlib.Status_Code is
   Count  : constant Natural := Natural (Input_Paths.Length);
   Inputs : Text_Array_Access := null;
   Names  : Text_Array_Access := null;
   Status : Zlib.Status_Code;
begin
   Inputs := new Zlib.Text_Array (1 .. Count);
   Names := new Zlib.Text_Array (1 .. Count);
   for I in 1 .. Count loop
      Inputs.all (I) := Input_Paths.Element (I);
      Names.all (I) := Entry_Names.Element (I);
   end loop;

   case Format is
      when Zip_Archive =>
         Files.Operations.Archives.Writing.ZIP_Files
           (Inputs.all, Staged, Names.all, Status);
      when Seven_Zip_Archive =>
         Zlib.Seven_Zip_Deflate_Files
           (Inputs.all, Staged, Names.all, Status => Status);
   end case;
   Free_Text_Array (Inputs);
   Free_Text_Array (Names);
   return Status;
exception
   when others =>
      Free_Text_Array (Inputs);
      Free_Text_Array (Names);
      raise;
end Write_Staged;
