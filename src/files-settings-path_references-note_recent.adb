separate (Files.Settings.Path_References)
   procedure Note_Recent
     (Settings : in out Settings_Model;
      Path     : String)
   is
      Index : Natural;
   begin
      if not Persistent_Path_Is_Valid (Path) then
         return;
      end if;

      --  Drop any earlier occurrence so the freshest position wins and the list
      --  stays duplicate-free.
      Index := Settings.Paths.Recent.First_Index;
      while Index <= Settings.Paths.Recent.Last_Index loop
         if Same (To_String (Settings.Paths.Recent.Element (Index)), Path) then
            Settings.Paths.Recent.Delete (Index);
         else
            Index := Index + 1;
         end if;
      end loop;

      Settings.Paths.Recent.Prepend (To_Unbounded_String (Path));

      --  Enforce the cap by discarding the oldest (tail) entries.
      while Natural (Settings.Paths.Recent.Length) > Max_Recent_Items loop
         Settings.Paths.Recent.Delete_Last;
      end loop;
   end Note_Recent;
