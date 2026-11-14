with Files.Folder_Tree;
with Files.Model.Tree_Panel;

separate (Files.Operations)
procedure Load_Tree_Children
  (Model      : in out Files.Model.Window_Model;
   Settings   : Files.Settings.Settings_Model;
   Node_Index : Positive)
is
   --  The tree shows folders only, read lean: this runs on the UI thread.
   Load     : constant Files.File_System.Directory_Load_Result :=
     Files.File_System.Load_Subdirectories
       (Files.Model.Tree_Panel.Node_Path (Model, Node_Index), Settings, Files.Settings.Listing_Options_Of (Settings));
   Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
begin
   if not Load.Success then
      Files.Model.Set_Error (Model, To_String (Load.Error_Key));
      return;
   end if;
   for Item of Load.Items loop
      if Item.Kind = Files.Types.Directory_Item then
         Children.Append
           (Files.Folder_Tree.Entry_Seed'
              (Path => Item.Full_Path,
               Name => Item.Name));
      end if;
   end loop;
   Files.Model.Tree_Panel.Set_Children (Model, Node_Index, Children);
end Load_Tree_Children;
