separate (Files.File_System)
function Make_Item
  (Parent_Path : String;
   Name        : String;
   Kind        : Files.Types.Item_Kind;
   Filetype    : String := "")
   return Directory_Item
is
   Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
   Type_Name : constant String :=
     (if Filetype /= "" then Filetype else Files.File_Types.Detect_Filetype (Settings, Kind, Name));
begin
   return
     (Name        => To_Unbounded_String (Name),
      Full_Path   => To_Unbounded_String (Join_Path (Parent_Path, Name)),
      Parent_Path => To_Unbounded_String (Parent_Path),
      Hidden      => Name'Length > 0 and then Name (Name'First) = '.',
      Kind        => Kind,
      Filetype    => To_Unbounded_String (Type_Name),
      Icon_Id     => To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Kind, Type_Name)),
      others      => <>);
end Make_Item;
