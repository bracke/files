with Files.File_System.Roots;
with Files.Settings.Path_References;
separate (Files.Operations)
function Root_Entries_With_Favorites
  (Settings : Files.Settings.Settings_Model)
   return Files.File_System.Root_Entry_Vectors.Vector
is
   Roots : Files.File_System.Root_Entry_Vectors.Vector := Files.File_System.Roots.Available_Root_Entries;
begin
   for Path of Files.Settings.Path_References.Favorite_Paths (Settings) loop
      Roots.Append
        (Files.File_System.Root_Entry'
           (Path        => Path,
            Label       =>
              To_Unbounded_String
                (Files.File_System.Roots.Root_Label (To_String (Path), Files.File_System.Root_Favorite)),
            Name        =>
              To_Unbounded_String
                (Files.File_System.Roots.Root_Name (To_String (Path), Files.File_System.Root_Favorite)),
            Detail      => Null_Unbounded_String,
            Kind        => Files.File_System.Root_Favorite,
            Volume_Name => Null_Unbounded_String,
            Removable   => False));
   end loop;
   return Roots;
end Root_Entries_With_Favorites;
