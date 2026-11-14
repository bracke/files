with Files.Helper_Modes;
separate (Files_Suite.Recovery)
   --  Every helper mode's flag reads back as that mode, and nothing else
   --  reads as one: the dispatcher answers a flag by its mode alone.
   procedure Test_Helper_Mode_Flags (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Files.Helper_Modes.Helper_Mode;
      Found : Boolean;
      Mode  : Files.Helper_Modes.Helper_Mode;
   begin
      for Each in Files.Helper_Modes.Helper_Mode loop
         Mode := Files.Helper_Modes.Mode_Of (Files.Helper_Modes.Flag (Each), Found);
         Assert (Found and then Mode = Each,
                 Files.Helper_Modes.Flag (Each) & " reads back as " & Files.Helper_Modes.Helper_Mode'Image (Each));
      end loop;
      for Other of Files.Types.String_Vectors.Vector'
        [To_Unbounded_String (Root), To_Unbounded_String ("--files-transfe")]
      loop
         declare
            Ignored : constant Files.Helper_Modes.Helper_Mode :=
              Files.Helper_Modes.Mode_Of (To_String (Other), Found);
            pragma Unreferenced (Ignored);
         begin
            Assert (not Found, To_String (Other) & " is no helper flag (a path, or a flag spelled almost right)");
         end;
      end loop;
   end Test_Helper_Mode_Flags;
