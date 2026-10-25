separate (Files_Suite.Operations)
   procedure Test_Job_Item_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Path      : constant String := Join (Root, "invalid-job-items");
      File      : Ada.Streams.Stream_IO.File_Type;
      Items     : Files.File_System.Item_Vectors.Vector;
      Item      : Files.File_System.Directory_Item;
      Signature : Files.File_System.Directory_Signature;
      Rejected  : Boolean := False;

      procedure Write_Raw_Items
        (Record_Path : String;
         Value       : Files.File_System.Directory_Item)
      is
         Stream : Ada.Streams.Stream_IO.Stream_Access;
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Record_Path);
         Stream := Ada.Streams.Stream_IO.Stream (File);
         Natural'Output (Stream, 1);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Name), Files.Job_Records.Max_Path_Length);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Full_Path), Files.Job_Records.Max_Path_Length);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Parent_Path), Files.Job_Records.Max_Path_Length);
         Files.Types.Item_Kind'Output (Stream, Value.Kind);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Filetype), Files.Job_Records.Max_Text_Length);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Icon_Id), Files.Job_Records.Max_Text_Length);
         Boolean'Output (Stream, Value.Size_Available);
         Long_Long_Integer'Output (Stream, Value.Size);
         Boolean'Output (Stream, Value.Creation_Available);
         Ada.Calendar.Time'Output (Stream, Value.Creation_Time);
         Boolean'Output (Stream, Value.Modified_Available);
         Ada.Calendar.Time'Output (Stream, Value.Modified_Time);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Permissions), Files.Job_Records.Max_Text_Length);
         Boolean'Output (Stream, Value.Mode_Available);
         Natural'Output (Stream, Value.Mode_Bits);
         Boolean'Output (Stream, Value.Ownership_Available);
         Natural'Output (Stream, Value.Owner_Id);
         Natural'Output (Stream, Value.Group_Id);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Filetype_Extra), Files.Job_Records.Max_Text_Length);
         Boolean'Output (Stream, Value.Filetype_Extra_Loaded);
         Boolean'Output (Stream, Value.Thumbnail_Available);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Thumbnail_Path), Files.Job_Records.Max_Path_Length);
         Natural'Output (Stream, Value.Thumbnail_Width);
         Natural'Output (Stream, Value.Thumbnail_Height);
         Natural'Output (Stream, Files.Shared_Bytes.Length (Value.Thumbnail_Pixels));
         for Byte of Files.Shared_Bytes.To_Vector (Value.Thumbnail_Pixels) loop
            Interfaces.Unsigned_8'Output (Stream, Byte);
         end loop;
         Boolean'Output (Stream, Value.Metadata_Error);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Error_Key), Files.Job_Records.Max_Error_Length);
         Ada.Streams.Stream_IO.Close (File);
      end Write_Raw_Items;

      procedure Write_Raw_Signature
        (Record_Path : String;
         Value       : Files.File_System.Directory_Signature)
      is
         Stream : Ada.Streams.Stream_IO.Stream_Access;
      begin
         Ada.Streams.Stream_IO.Create
           (File, Ada.Streams.Stream_IO.Out_File, Record_Path);
         Stream := Ada.Streams.Stream_IO.Stream (File);
         Files.Job_Records.Write_String
           (Stream, To_String (Value.Path), Files.Job_Records.Max_Path_Length);
         Boolean'Output (Stream, Value.Exists);
         Natural'Output (Stream, Value.Entry_Count);
         Natural'Output (Stream, Value.Entry_State_Checksum);
         Ada.Calendar.Time'Output (Stream, Value.Latest_Modified);
         Boolean'Output (Stream, Value.Latest_Modified_Known);
         Ada.Streams.Stream_IO.Close (File);
      end Write_Raw_Signature;
   begin
      Reset_Root;
      Signature.Path := To_Unbounded_String ("relative-signature");
      Write_Raw_Signature (Path, Signature);
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, Path);
      Rejected := False;
      begin
         Signature := Files.Job_Records.Read_Signature
           (Ada.Streams.Stream_IO.Stream (File));
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (Rejected,
         "decoded directory signatures reject relative operational paths");

      Signature.Path := To_Unbounded_String
        (Root & Character'Val (0) & "ignored");
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Path);
      Rejected := False;
      begin
         Files.Job_Records.Write_Signature
           (Ada.Streams.Stream_IO.Stream (File), Signature);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (Rejected,
         "directory signatures with NUL-containing paths are not serialized");

      Item.Thumbnail_Available := True;
      Item.Thumbnail_Width := Natural'Last;
      Item.Thumbnail_Height := 1;
      Item.Thumbnail_Pixels := Files.Shared_Bytes.To_Shared ([1 => 0]);
      Items.Append (Item);
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Rejected := False;
      begin
         Files.Job_Records.Write_Items
           (Ada.Streams.Stream_IO.Stream (File), Items);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "invalid thumbnail dimensions are not serialized");

      Item := Files.File_System.Make_Item
        (Root, "transport-item", Files.Types.Regular_File_Item);
      Item.Full_Path := To_Unbounded_String ("relative-transport-item");
      Write_Raw_Items (Path, Item);
      Ada.Streams.Stream_IO.Open
        (File, Ada.Streams.Stream_IO.In_File, Path);
      Rejected := False;
      begin
         Items := Files.Job_Records.Read_Items
           (Ada.Streams.Stream_IO.Stream (File));
      exception
         when Ada.IO_Exceptions.Data_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (Rejected,
         "decoded job items reject relative operational paths");

      Item.Full_Path := To_Unbounded_String (Join (Root, "transport-item"));
      Item.Parent_Path := To_Unbounded_String
        (Root & Character'Val (0) & "ignored");
      Items.Clear;
      Items.Append (Item);
      Ada.Streams.Stream_IO.Create
        (File, Ada.Streams.Stream_IO.Out_File, Path);
      Rejected := False;
      begin
         Files.Job_Records.Write_Items
           (Ada.Streams.Stream_IO.Stream (File), Items);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert
        (Rejected,
         "job items with NUL-containing parent paths are not serialized");
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Job_Item_Record_Validation;
