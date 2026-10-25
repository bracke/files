separate (Files.Operations)
--  Build the paste work-list from validated plans: one item per valid plan,
--  skipping a move whose destination equals its source (moving an item into
--  the directory it already lives in is a no-op).
function Paste_Work_List
  (Plans     : Files.File_System.Drop_Import_Plan_Vectors.Vector;
   Directory : String)
   return Files.Paste.Work_Item_Vectors.Vector
is
   Work : Files.Paste.Work_Item_Vectors.Vector;
begin
   for Plan of Plans loop
      if Plan.Valid
        and then not (Plan.Mode = Files.File_System.Drop_Move
                      and then Plan.Source_Path = Plan.Destination_Path)
      then
         Work.Append
           (Files.Paste.Work_Item'
              (Source_Path => Plan.Source_Path,
               Dest_Dir    => To_Unbounded_String (Directory),
               Dest_Name   =>
                 To_Unbounded_String
                   (Ada.Directories.Simple_Name (To_String (Plan.Source_Path)))));
      end if;
   end loop;
   return Work;
end Paste_Work_List;
