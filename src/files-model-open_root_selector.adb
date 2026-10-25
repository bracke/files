separate (Files.Model)
procedure Open_Root_Selector
  (Model : in out Window_Model;
   Roots : Files.Types.String_Vectors.Vector)
is
   Entries : Files.File_System.Root_Entry_Vectors.Vector;
begin
   Model.Revision_Value := Model.Revision_Value + 1;
   for Root of Roots loop
      Entries.Append
        (Files.File_System.Root_Entry'
           (Path  => Root,
            Label => Root,
            Kind  => Files.File_System.Root_Filesystem,
            Volume_Name => Root,
            Ready => Files.File_System.Root_Ready,
            Removable => False));
   end loop;

   Open_Root_Selector (Model, Entries);
end Open_Root_Selector;
