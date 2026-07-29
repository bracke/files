separate (Files.File_System)
   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String is
   begin
      if Parent_Path = "" then
         return Name;
      end if;

      return Ada.Directories.Compose
        (Containing_Directory => Parent_Path,
         Name                 => Name);

   exception
      when others =>
         --  Compose raises Name_Error for a name the host cannot represent --
         --  ':' and '\' are ordinary characters on POSIX but illegal on Windows.
         --  Joining is not the place to decide that: callers validate names
         --  themselves and report a rejection, and they need a path back in
         --  order to do it. Raising here turned "that name is not allowed" into
         --  a crash on Windows alone.
         declare
            Separator : constant Character := GNAT.OS_Lib.Directory_Separator;
         begin
            if Parent_Path (Parent_Path'Last) = Separator
              or else Parent_Path (Parent_Path'Last) = '/'
            then
               return Parent_Path & Name;
            end if;

            return Parent_Path & Separator & Name;
         end;
   end Join_Path;
