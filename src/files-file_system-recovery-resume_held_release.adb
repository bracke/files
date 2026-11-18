separate (Files.File_System.Recovery)
   function Resume_Held_Release (Path : String) return Boolean is
      Stage  : constant String := Files.Fs_Primitives.Parent_Directory (Path);
      Holder : constant String := Hostkit.Fs.Join (Stage, "release");
      Held   : UString;
      Count  : Natural := 0;

      procedure Count_One (Name : String; Stop : in out Boolean) is
         pragma Unreferenced (Stop);
      begin
         Count := Count + 1;
         Held := To_Unbounded_String (Hostkit.Fs.Join (Holder, Name));
      end Count_One;
   begin
      --  refusal-safe: a refused payload goes on to the no-replace move back, which refuses an occupied one
      if Files.Fs_Primitives.Entry_Exists (Path)
        or else Hostkit.Fs.Is_Link (Holder)
        or else not Files.Fs_Primitives.Directory_Exists (Holder)
      then
         --  refusal-safe: a refused payload keeps the release marker
         return Files.Fs_Primitives.Entry_Exists (Path);
      end if;
      Files.Fs_Primitives.For_Each_Name (Holder, Count_One'Access);
      declare
         --  Release names the held entry after the original; anything else
         --  (a stage a nested move left there) is not this payload.
         Original : constant String := Original_Path (Path);
         Leaf     : constant String :=
           (if Valid_Absolute_Path (Original) then Files.Fs_Primitives.Leaf_Text (Original) else "recovered");
      begin
         if Count = 0 then
            Files.Fs_Primitives.Delete_Directory (Holder);
         elsif Count = 1
           and then Files.Fs_Primitives.Leaf_Text (To_String (Held)) = Leaf
           and then Support.Move_No_Replace (To_String (Held), Path)
         then
            Files.Fs_Primitives.Delete_Directory (Holder);
         end if;
      end;
      --  refusal-safe: a refused payload keeps the release marker
      return Files.Fs_Primitives.Entry_Exists (Path);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.File_System.Recovery");
         return False;
   end Resume_Held_Release;
