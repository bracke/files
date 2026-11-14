separate (Files_Suite.Names)
   --  The "stem 2.ext" a paste or drop gives a name in use stays storable:
   --  a 254-byte name numbered as it is would take 256 bytes, so its stem
   --  is cut, and the counter and the extension are kept.
   procedure Test_Numbered_Name_Fits (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Long_Name : constant String := [1 .. 250 => 'n'] & ".txt";
      E_Acute   : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);

      function Accented (Count : Natural) return String is (Ada.Strings.Fixed."*" (Count, E_Acute));

      Accented_Name : constant String := Accented (125) & ".txt";

      function Taken (Leaf : String) return Boolean is (Leaf = Long_Name or else Leaf = Accented_Name);
   begin
      declare
         Free : constant String := Files.Paste.First_Free_Name (Long_Name, Taken'Access);
      begin
         Assert (Free'Length <= 255, "a numbered long name fits in 255 bytes:" & Natural'Image (Free'Length));
         Files_Suite.Support.Assert_Equal
           (Free, [1 .. 249 => 'n'] & " 2.txt", "the stem is cut and the counter and extension are kept");
      end;
      declare
         Free : constant String := Files.Paste.First_Free_Name (Accented_Name, Taken'Access);
      begin
         Assert (Free'Length <= 255, "a numbered two-byte name fits in 255 bytes");
         Files_Suite.Support.Assert_Equal
           (Free, Accented (124) & " 2.txt", "cut at a whole character");
      end;
      Files_Suite.Support.Assert_Equal
        (Files.Paste.First_Free_Name (Accented_Name, Taken'Access, Dos_Rules => True),
         Accented (125) & " 2.txt",
         "under DOS rules 131 UTF-16 units fit, so nothing is cut");
      Files_Suite.Support.Assert_Equal
        (Files.Paste.First_Free_Name ("short.txt", Taken'Access), "short.txt", "a free name is kept");
   end Test_Numbered_Name_Fits;
