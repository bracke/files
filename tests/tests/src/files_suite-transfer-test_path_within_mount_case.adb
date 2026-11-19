with Files.File_System.Testing;
separate (Files_Suite.Transfer)
   --  A folder's own name compares by the rule of the folder it is in, not
   --  by its own volume's: a case-folding stick mounted at /media/u/STICK
   --  does not take in /media/u/stick, a different folder of a volume that
   --  tells case apart. Below it, and where the holder folds too, case does
   --  not matter.
   procedure Test_Path_Within_Mount_Case (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  Only the stick folds names.
      function Stick_Folds (Directory : String) return Boolean is (Directory = "/media/u/STICK");

      --  Every volume folds, as on Windows or macOS.
      function All_Fold (Directory : String) return Boolean is
         pragma Unreferenced (Directory);
      begin
         return True;
      end All_Fold;

      function Within (Child, Parent : String; Everywhere : Boolean := False) return Boolean is
        (if Everywhere
         then Files.File_System.Testing.Path_Is_Within (Child, Parent, All_Fold'Access)
         else Files.File_System.Testing.Path_Is_Within (Child, Parent, Stick_Folds'Access));
   begin
      Assert (Within ("/media/u/STICK/notes", "/media/u/STICK"), "a path below the mount is within it");
      Assert (not Within ("/media/u/stick/notes", "/media/u/STICK"),
              "another folder whose name differs by case alone is not the mount");
      Assert (not Within ("/media/u/stick", "/media/u/STICK"), "nor is that folder itself");
      Assert (Within ("/media/u/STICK/DOCS/a", "/media/u/STICK/docs"),
              "below the mount, names compare by the stick's own folding");
      Assert (Within ("/media/u/stick/notes", "/media/u/STICK", Everywhere => True),
              "where the folder holding the mount folds names, the spellings are one folder");
      Assert (not Within ("/media/u/STICKY", "/media/u/STICK", Everywhere => True),
              "a longer name is never within, folded or not");
   end Test_Path_Within_Mount_Case;
