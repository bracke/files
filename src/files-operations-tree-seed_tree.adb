with Files.File_System_Types;
with Files.Folder_Tree;
with Files.Root_Labels;
with Files.Model.Tree_Panel;

separate (Files.Operations.Tree)
procedure Seed_Tree
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
is
   use type Files.File_System_Types.Root_Kind;
   Seeds : Files.Folder_Tree.Entry_Seed_Vectors.Vector;
begin
   for Root of Root_Entries_With_Favorites (Settings) loop
      Seeds.Append
        (Files.Folder_Tree.Entry_Seed'
           (Path => Root.Path,
            Name =>
              (if Root.Kind /= Files.File_System_Types.Root_Favorite
               then To_Unbounded_String (Files.Root_Labels.Display_Label (Root))
               else Root.Path)));
   end loop;
   if not Files.Model.Tree_Panel.Is_Seeded (Model) or else not Files.Model.Tree_Panel.Roots_Match (Model, Seeds) then
      Files.Model.Tree_Panel.Seed (Model, Seeds);
   end if;
end Seed_Tree;
