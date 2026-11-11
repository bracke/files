separate (Files_Suite.Operations)
   procedure Test_Path_Move_Record_Validation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Types.Path_Move_Kind;
      Path     : constant String := Join (Root, "path-moves");
      File     : Ada.Streams.Stream_IO.File_Type;
      Moves    : Files.Types.Path_Move_Vectors.Vector;
      Decoded  : Files.Types.Path_Move_Vectors.Vector;
      Rejected : Boolean := False;

      --  Whether reading back what Write left at Path is refused.
      function Read_Is_Rejected
        (Write : not null access procedure (Stream : not null access Ada.Streams.Root_Stream_Type'Class))
         return Boolean
      is
         Refused : Boolean := False;
      begin
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
         Write (Ada.Streams.Stream_IO.Stream (File));
         Ada.Streams.Stream_IO.Close (File);
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
         begin
            Decoded := Files.Job_Records.Read_Path_Moves (Ada.Streams.Stream_IO.Stream (File));
         exception
            when Ada.IO_Exceptions.Data_Error => Refused := True;
         end;
         Ada.Streams.Stream_IO.Close (File);
         return Refused;
      end Read_Is_Rejected;

      --  A move that claims to be a removal but names where it went.
      procedure Write_Removal_With_Target (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         Natural'Output (Stream, 1);
         Natural'Output (Stream, Files.Types.Path_Move_Kind'Pos (Files.Types.Removed));
         Files.Job_Records.Write_String (Stream, "/a", Files.Job_Records.Max_Path_Length);
         Files.Job_Records.Write_String (Stream, "/b", Files.Job_Records.Max_Path_Length);
      end Write_Removal_With_Target;

      --  A kind past the last one there is.
      procedure Write_Unknown_Kind (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         Natural'Output (Stream, 1);
         Natural'Output (Stream, Files.Types.Path_Move_Kind'Pos (Files.Types.Path_Move_Kind'Last) + 1);
         Files.Job_Records.Write_String (Stream, "/a", Files.Job_Records.Max_Path_Length);
         Files.Job_Records.Write_String (Stream, "/b", Files.Job_Records.Max_Path_Length);
      end Write_Unknown_Kind;

      --  More moves than one record may carry.
      procedure Write_Too_Many (Stream : not null access Ada.Streams.Root_Stream_Type'Class) is
      begin
         Natural'Output (Stream, Files.Job_Records.Max_Path_Moves + 1);
      end Write_Too_Many;
   begin
      Reset_Root;

      --  A move and a removal round-trip in order, each with its kind.
      Moves.Append
        (Files.Types.Path_Move'
           (From => To_Unbounded_String ("/old/a.txt"), To => To_Unbounded_String ("/new/a.txt"),
            Kind => Files.Types.Moved));
      Moves.Append
        (Files.Types.Path_Move'
           (From => To_Unbounded_String ("/old/b.txt"), To => Null_Unbounded_String, Kind => Files.Types.Removed));
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Files.Job_Records.Write_Path_Moves (Ada.Streams.Stream_IO.Stream (File), Moves);
      Ada.Streams.Stream_IO.Close (File);
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);
      Decoded := Files.Job_Records.Read_Path_Moves (Ada.Streams.Stream_IO.Stream (File));
      Ada.Streams.Stream_IO.Close (File);
      Files_Suite.Support.Assert_Equal (Natural (Decoded.Length), 2, "both path moves read back");
      Assert (Decoded (1).Kind = Files.Types.Moved, "the first path move reads back as a move");
      Files_Suite.Support.Assert_Equal (To_String (Decoded (1).From), "/old/a.txt", "a move keeps its old path");
      Files_Suite.Support.Assert_Equal (To_String (Decoded (1).To), "/new/a.txt", "a move keeps its new path");
      Assert (Decoded (2).Kind = Files.Types.Removed, "the second path move reads back as a removal");
      Files_Suite.Support.Assert_Equal (To_String (Decoded (2).From), "/old/b.txt", "a removal keeps its path");
      Files_Suite.Support.Assert_Equal (To_String (Decoded (2).To), "", "a removal names no new path");

      --  A move whose kind and new path disagree is not written ...
      Moves.Clear;
      Moves.Append
        (Files.Types.Path_Move'
           (From => To_Unbounded_String ("/old/c.txt"), To => Null_Unbounded_String, Kind => Files.Types.Moved));
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      begin
         Files.Job_Records.Write_Path_Moves (Ada.Streams.Stream_IO.Stream (File), Moves);
      exception
         when Ada.Directories.Use_Error => Rejected := True;
      end;
      Ada.Streams.Stream_IO.Close (File);
      Assert (Rejected, "a move without a new path is not serialized");

      --  ... nor read back, and neither is an unknown kind or too many moves.
      Assert
        (Read_Is_Rejected (Write_Removal_With_Target'Access),
         "a decoded removal that names a new path is rejected");
      Assert (Read_Is_Rejected (Write_Unknown_Kind'Access), "a decoded path move of an unknown kind is rejected");
      Assert (Read_Is_Rejected (Write_Too_Many'Access), "a decoded record with too many path moves is rejected");
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Test_Path_Move_Record_Validation;
