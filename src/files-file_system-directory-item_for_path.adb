separate (Files.File_System.Directory)
   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item
   is
      Filetype : constant String := Files.File_Types.Detect_Filetype (Settings, Kind, Name);
      Icon_Id  : constant String := Files.File_Types.Icon_Id_For (Settings, Kind, Filetype);
      Thumbnail_Cache : constant String := Default_Thumbnail_Cache_Directory (Parent_Path);
      Thumbnail_Path  : constant String := Thumbnail_Path_For (Full, Thumbnail_Cache);
      Thumbnail : constant Cached_Thumbnail :=
        Thumbnail_For_Item
          (Full_Path       => Full,
           Kind            => Kind,
           Filetype        => Filetype,
           Name            => Name,
           Icon_Id         => Icon_Id,
           Cache_Directory => Thumbnail_Cache,
           Thumbnail_Path  => Thumbnail_Path);
      Item : Directory_Item :=
        (Name               => To_Unbounded_String (Name),
         Full_Path          => To_Unbounded_String (Full),
         Parent_Path        => To_Unbounded_String (Parent_Path),
         Kind               => Kind,
         Filetype           => To_Unbounded_String (Filetype),
         Icon_Id            => To_Unbounded_String (Icon_Id),
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
         Thumbnail_Available => False,
         Thumbnail_Path      => Null_Unbounded_String,
         Thumbnail_Width     => 0,
         Thumbnail_Height    => 0,
         Thumbnail_Pixels    => Files.Types.Byte_Vectors.Empty_Vector,
         Metadata_Error     => False,
         Error_Key          => Null_Unbounded_String);
   begin
      --  Filetype_Extra (folder item counts, document page/entry/line counts,
      --  symlink targets) is computed lazily for the selected item when the info
      --  pane needs it -- see Files.Model.Ensure_Selected_Item_Extra -- rather
      --  than here, where it would open every subfolder and read every document
      --  on load, making navigation slow. It stays empty at load time.
      begin
         if Kind /= Files.Types.Directory_Item then
            Item.Size := Long_Long_Integer (Ada.Directories.Size (Full));
            Item.Size_Available := True;
            if Thumbnail.Loaded then
               Item.Thumbnail_Available := True;
               Item.Thumbnail_Path := To_Unbounded_String (Thumbnail_Path);
               Item.Thumbnail_Width := Thumbnail.Width;
               Item.Thumbnail_Height := Thumbnail.Height;
               Item.Thumbnail_Pixels := Thumbnail.Pixels;
            end if;
         end if;
         Item.Creation_Time :=
           Files.Platform.Metadata.File_Creation_Time (Full, Item.Creation_Available);
         Item.Modified_Time := Ada.Directories.Modification_Time (Full);
         Item.Modified_Available := True;
         Item.Permissions := To_Unbounded_String (Permission_String (Full));
         Files.Platform.Metadata.File_Mode_And_Ownership
           (Full,
            Item.Mode_Bits, Item.Mode_Available,
            Item.Owner_Id, Item.Group_Id, Item.Ownership_Available);
      exception
         when others =>
            Item.Metadata_Error := True;
            Item.Error_Key := To_Unbounded_String ("error.metadata.read");
      end;

      return Item;
   end Item_For_Path;
