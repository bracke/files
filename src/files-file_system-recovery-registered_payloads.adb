with Files.Text_Basics;

separate (Files.File_System.Recovery)
   function Registered_Payloads return Files.Types.String_Vectors.Vector is
      Root : constant String := Registry_Root (Create => False);
      Result : Files.Types.String_Vectors.Vector;
      Seen   : Path_Sets.Set;

      procedure Check (Name : String; Stop : in out Boolean) is
         pragma Unreferenced (Stop);
         Payload, Expected : UString;
         Directory : constant String := Hostkit.Fs.Join (Root, Name);
      begin
         if Files.Text_Basics.Starts_With (Name, Files.Protocol_Names.Recovery_Stage_Prefix)
           and then Files.IO.Fs_Primitives.Directory_Exists (Directory)
           and then Read_Registry_Record (Directory, Payload, Expected)
           and then not Seen.Contains (To_String (Payload))
           and then Recognizes (To_String (Payload))
           and then Stage_Matches (To_String (Payload), To_String (Expected))
         then
            Seen.Include (To_String (Payload));
            Result.Append (Payload);
         end if;
      end Check;
   begin
      if Root = "" then
         return Result;
      end if;
      Files.IO.Fs_Primitives.For_Each_Name (Root, Check'Access);
      return Result;
   exception
      when Failure : others =>
         Files.Diagnostics.Note (Failure, "Files.File_System.Recovery");
         return Result;
   end Registered_Payloads;
