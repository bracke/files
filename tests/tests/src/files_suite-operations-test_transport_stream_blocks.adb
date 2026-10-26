separate (Files_Suite.Operations)
   procedure Test_Transport_Stream_Blocks (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Ada.Streams.Stream_Element_Offset;
      use type Ada.Streams.Stream_Element_Array;
      --  Single elements, a run longer than a block, then single elements
      --  again: every path through the write and read blocks.
      Small_Count : constant := 20_000;
      Large : Ada.Streams.Stream_Element_Array (1 .. 40_000);
      Path   : constant String := Join (Root, "transport-blocks");
      Output : aliased Files.Exclusive_Streams.Output_Stream;
      Input  : aliased Files.Lease_Streams.Input_Stream;
      Same   : Boolean := True;
   begin
      Reset_Root;
      for Index in Large'Range loop
         Large (Index) := Ada.Streams.Stream_Element (Index mod 251);
      end loop;
      Files.Exclusive_Streams.Create (Output, Path);
      for Index in 1 .. Small_Count loop
         Interfaces.Unsigned_8'Output (Output'Access, Interfaces.Unsigned_8 (Index mod 256));
      end loop;
      Output.Write (Large);
      for Index in 1 .. Small_Count loop
         Natural'Output (Output'Access, Index);
      end loop;
      Assert
        (Files.Exclusive_Streams.Size (Output) = Long_Long_Integer (Small_Count * 5 + Large'Length),
         "an exclusive stream's size counts the bytes it has not written out yet");
      Files.Exclusive_Streams.Close (Output);
      Assert
        (Ada.Directories.Size (Path) = Ada.Directories.File_Size (Small_Count * 5 + Large'Length),
         "closing an exclusive stream writes out every buffered byte");

      Assert (Files.Lease_Streams.Open (Path, Input) = Hostkit.Lease_Files.Opened, "the transport file opens");
      for Index in 1 .. Small_Count loop
         if Interfaces.Unsigned_8'Input (Input'Access) /= Interfaces.Unsigned_8 (Index mod 256) then
            Same := False;
         end if;
      end loop;
      declare
         Back : Ada.Streams.Stream_Element_Array (Large'Range);
         Last : Ada.Streams.Stream_Element_Offset;
      begin
         Input.Read (Back, Last);
         Same := Same and then Last = Back'Last and then Back = Large;
      end;
      for Index in 1 .. Small_Count loop
         if Natural'Input (Input'Access) /= Index then
            Same := False;
         end if;
      end loop;
      Assert (Same, "a lease stream reads back across its blocks exactly what was written");
      Assert (Files.Lease_Streams.End_Of_Stream (Input), "a lease stream ends after the last byte");
      begin
         declare
            Extra : constant Interfaces.Unsigned_8 := Interfaces.Unsigned_8'Input (Input'Access);
            pragma Unreferenced (Extra);
         begin
            Assert (False, "a lease stream refuses to read past its end");
         end;
      exception
         when Ada.IO_Exceptions.End_Error => null;
      end;
      Files.Lease_Streams.Release (Input);
      Ada.Directories.Delete_File (Path);
   exception
      when others =>
         Files.Exclusive_Streams.Close_Safely (Output);
         Files.Lease_Streams.Release (Input);
         raise;
   end Test_Transport_Stream_Blocks;
