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
     (Name               => To_Unbounded_String (Name),
      Full_Path          => To_Unbounded_String (Join_Path (Parent_Path, Name)),
      Parent_Path        => To_Unbounded_String (Parent_Path),
      Hidden             => Name'Length > 0 and then Name (Name'First) = '.',
      Kind               => Kind,
      Filetype           => To_Unbounded_String (Type_Name),
      Icon_Id            => To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Kind, Type_Name)),
      Size_Available     => False,
      Size               => 0,
      Creation_Available => False,
      Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
      Modified_Available => False,
      Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
      Permissions        => Null_Unbounded_String,
      Mode_Available     => False,
      Mode_Bits          => 0,
      Ownership_Available => False,
      Owner_Id           => 0,
      Group_Id           => 0,
      Filetype_Extra     => Null_Unbounded_String,
      Filetype_Extra_Loaded => False,
      Thumbnail_Available => False,
      Thumbnail_Path      => Null_Unbounded_String,
      Thumbnail_Width     => 0,
      Thumbnail_Height    => 0,
      Thumbnail_Pixels    => Files.Shared_Bytes.Empty,
      Metadata_Error     => False,
      Error_Key          => Null_Unbounded_String);
end Make_Item;
