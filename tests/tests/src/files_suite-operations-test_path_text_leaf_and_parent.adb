with Files.Fs_Primitives;

separate (Files_Suite.Operations)
   --  GNAT's Windows runtime refuses a path component over 256 characters, so
   --  a 300-character name came back with no leaf and was "an invalid name"
   --  there, never reaching the filesystem's own "too long". The text-only
   --  reading it falls back to splits Windows and POSIX paths on any host.
   procedure Test_Path_Text_Leaf_And_Parent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package P renames Files.Fs_Primitives;
      Long : constant String := [1 .. 300 => 'n'];
   begin
      Files_Suite.Support.Assert_Equal (P.Leaf_Text ("C:\dir\" & Long), Long, "a long Windows leaf");
      Files_Suite.Support.Assert_Equal (P.Parent_Text ("C:\dir\" & Long), "C:\dir", "and its parent");
      Files_Suite.Support.Assert_Equal (P.Parent_Text ("C:\" & Long), "C:\", "a drive root keeps its separator");
      Files_Suite.Support.Assert_Equal (P.Leaf_Text ("C:\"), "", "a drive root has no leaf");
      Files_Suite.Support.Assert_Equal (P.Leaf_Text ("/a/b/"), "b", "trailing separators are not a component");
      Files_Suite.Support.Assert_Equal (P.Parent_Text ("/a/b/"), "/a", "nor part of the parent");
      Files_Suite.Support.Assert_Equal (P.Parent_Text ("/x"), "/", "the POSIX root keeps its separator");
      Files_Suite.Support.Assert_Equal (P.Leaf_Text ("/"), "", "the POSIX root has no leaf");
      Files_Suite.Support.Assert_Equal (P.Parent_Text ("\\server\share\" & Long), "\\server\share", "a share");
   end Test_Path_Text_Leaf_And_Parent;
