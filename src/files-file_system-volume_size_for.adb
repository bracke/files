separate (Files.File_System)
   procedure Volume_Size_For
     (Path : String;
      Info : out Volume_Size_Info)
   is
      Capacity : constant Files.Platform.Metadata.Volume_Capacity :=
        Files.Platform.Metadata.Volume_Capacity_Of (Path);
   begin
      Info :=
        (Capacity_Bytes   => Capacity.Capacity_Bytes,
         Free_Bytes       => Capacity.Free_Bytes,
         Inode_Count      => Capacity.Inode_Count,
         Free_Inode_Count => Capacity.Free_Inode_Count,
         Name_Max         => Capacity.Name_Max,
         Read_Only        => Capacity.Read_Only,
         Known            => Capacity.Available,
         Inodes_Known     => Capacity.Inodes_Known,
         Name_Max_Known   => Capacity.Name_Max_Known,
         Read_Only_Known  => Capacity.Read_Only_Known);
   end Volume_Size_For;
