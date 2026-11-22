separate (Files.File_System.Roots.Available_Root_Entries)
procedure Append_Children
  (Parent   : String;
   Kind     : Root_Kind;
   Per_User : Boolean := False)
is
   procedure Visit (Name : String; Stop : in out Boolean) is
      Full : constant String := Hostkit.Fs.Join (Parent, Name);
   begin
      if Root_Entries_Scanned >= Max_Root_Entries_Scanned
        or else Natural (Roots.Length) >= Max_Discovered_Roots
      then
         Stop := True;
         return;
      end if;
      --  Folders only, a link to one included.
      if not Files.IO.Fs_Primitives.Directory_Exists (Full) then
         return;
      end if;
      Root_Entries_Scanned := Root_Entries_Scanned + 1;
      --  A volumes folder may hold one folder of mounts per user
      --  (/media/<user>, /run/media/<user>): this user's is opened;
      --  in a folder of nothing else, another user's is passed by.
      if User_Name /= "" and then Name = User_Name then
         Append_Children (Full, Kind);
      elsif not Per_User then
         Append_If_Directory (Full, Kind);
      end if;
   end Visit;
begin
   if Root_Entries_Scanned >= Max_Root_Entries_Scanned
     or else Natural (Roots.Length) >= Max_Discovered_Roots
     or else not Files.IO.Fs_Primitives.Directory_Exists (Parent)
   then
      return;
   end if;

   Files.IO.Fs_Primitives.For_Each_Name (Parent, Visit'Access);
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System");
end Append_Children;
