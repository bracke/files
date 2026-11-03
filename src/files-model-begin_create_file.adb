separate (Files.Model)
procedure Begin_Create_File
   (Model : in out Window_Model;
    Name  : String) is
begin
   Touch (Model);
   Begin_Create_Temporary (Model, Name, Is_Directory => False);
end Begin_Create_File;
