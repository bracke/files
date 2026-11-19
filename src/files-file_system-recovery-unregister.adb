separate (Files.File_System.Recovery)
   procedure Unregister (Payload : String) is
      Root : constant String := Registry_Root (Create => False);
      Hold : Registry_Hold;

      procedure Check (Name : String; Stop : in out Boolean) is
         pragma Unreferenced (Stop);
         Recorded, Identity : UString;
         Directory : constant String := Hostkit.Fs.Join (Root, Name);
      begin
         if Files.Types.Starts_With (Name, Files.Protocol_Names.Recovery_Stage_Prefix)
           and then Files.Fs_Primitives.Directory_Exists (Directory)
           and then Read_Registry_Record (Directory, Recorded, Identity)
           and then To_String (Recorded) = Payload
         then
            Delete_Registry_Record (Directory);
         end if;
      end Check;
   begin
      if Root = "" then
         return;
      end if;
      Hold_Registry (Root, Hold);
      Files.Fs_Primitives.For_Each_Name (Root, Check'Access);
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System.Recovery");
   end Unregister;
