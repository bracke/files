separate (Files.File_System)
   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details
   is
      Path_Text : constant String := To_String (Root.Path);

      function Path_Is_Queryable return Boolean is
      begin
         if Path_Text = "" then
            return False;
         end if;

         for Character_Value of Path_Text loop
            if Character'Pos (Character_Value) < 32
              or else Character'Pos (Character_Value) = 127
            then
               return False;
            end if;
         end loop;

         return True;
      end Path_Is_Queryable;

      Queryable : constant Boolean := Path_Is_Queryable;
      Mount     : constant Mount_Metadata :=
        (if Queryable then Mount_Metadata_For_Root (Path_Text) else (others => <>));
      Volume    : Volume_Size_Info := (others => <>);

      function Adapter_Name return String is
         Has_Statvfs : constant Boolean := Volume.Known;
         Has_Proc    : constant Boolean := Mount.Found;
         Has_Sysfs   : constant Boolean := Mount.Removable_Known;
      begin
         if Has_Statvfs and then Has_Proc and then Has_Sysfs then
            return "statvfs+proc.mounts+sysfs";
         elsif Has_Statvfs and then Has_Proc then
            return "statvfs+proc.mounts";
         elsif Has_Statvfs then
            return "statvfs";
         elsif Has_Proc and then Has_Sysfs then
            return "proc.mounts+sysfs";
         elsif Has_Proc then
            return "proc.mounts";
         elsif Has_Sysfs then
            return "sysfs";
         else
            return "none";
         end if;
      end Adapter_Name;

      function Network_Filesystem_Type (Filesystem_Type : String) return Boolean is
         Normalized : constant String := Files.Types.To_Lower (Filesystem_Type);
      begin
         return Normalized = "9p"
           or else Normalized = "afpfs"
           or else Normalized = "cifs"
           or else Normalized = "davfs"
           or else Normalized = "fuse.gvfsd-fuse"
           or else Normalized = "fuse.sshfs"
           or else Normalized = "ncpfs"
           or else Normalized = "nfs"
           or else Normalized = "nfs4"
           or else Normalized = "smb3"
           or else Normalized = "sshfs";
      end Network_Filesystem_Type;

      function Path_Starts_With (Prefix : String) return Boolean is
      begin
         return Path_Text'Length >= Prefix'Length
           and then Path_Text (Path_Text'First .. Path_Text'First + Prefix'Length - 1) = Prefix;
      end Path_Starts_With;

      function Network_Root return Boolean is
      begin
         return Root.Kind = Root_Network_Mount
           or else Network_Filesystem_Type (To_String (Mount.Filesystem_Type))
           or else Path_Starts_With ("//")
           or else Path_Starts_With ("\\");
      end Network_Root;

      function Remote_Protocol_For return String is
         Path_Lower : constant String := Files.Types.To_Lower (Path_Text);
         Type_Lower : constant String := Files.Types.To_Lower (To_String (Mount.Filesystem_Type));
      begin
         if Type_Lower = "cifs" or else Type_Lower = "smb3" then
            return "smb";
         elsif Type_Lower = "nfs" or else Type_Lower = "nfs4" then
            return "nfs";
         elsif Type_Lower = "sshfs" or else Type_Lower = "fuse.sshfs" then
            return "sshfs";
         elsif Type_Lower = "davfs" then
            return "webdav";
         elsif Type_Lower = "afpfs" then
            return "afp";
         elsif Type_Lower = "9p" then
            return "9p";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "smb-share:") > 0
           or else Path_Starts_With ("//")
           or else Path_Starts_With ("\\")
         then
            return "smb";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "sftp:") > 0 then
            return "sftp";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "dav:") > 0
           or else Ada.Strings.Fixed.Index (Path_Lower, "davs:") > 0
         then
            return "webdav";
         elsif Ada.Strings.Fixed.Index (Path_Lower, "afp-volume:") > 0 then
            return "afp";
         elsif Type_Lower = "fuse.gvfsd-fuse"
           or else Ada.Strings.Fixed.Index (Path_Lower, "/gvfs/") > 0
         then
            return "gvfs";
         elsif Network_Root then
            return "unknown";
         else
            return "";
         end if;
      end Remote_Protocol_For;

      function Auth_May_Be_Required_For (Protocol : String) return Boolean is
      begin
         return Protocol = "afp"
           or else Protocol = "sftp"
           or else Protocol = "smb"
           or else Protocol = "sshfs"
           or else Protocol = "webdav";
      end Auth_May_Be_Required_For;
   begin
      if Queryable then
         Volume_Size_For (Path_Text, Volume);
      end if;

      declare
         Is_Network : constant Boolean := Network_Root;
         Protocol   : constant String := Remote_Protocol_For;
      begin
         return
           (Path                 => Root.Path,
            Label                => Root.Volume_Name,
            Native_Api_Name      => To_Unbounded_String (Adapter_Name),
            Filesystem_Type      => Mount.Filesystem_Type,
            Source_Device        => Mount.Source_Device,
            Mount_Options        => Mount.Mount_Options,
            Capacity_Bytes       => Volume.Capacity_Bytes,
            Free_Bytes           => Volume.Free_Bytes,
            Inode_Count          => Volume.Inode_Count,
            Free_Inode_Count     => Volume.Free_Inode_Count,
            Capacity_Known       => Volume.Known,
            Free_Known           => Volume.Known,
            Inode_Count_Known    => Volume.Inodes_Known,
            Free_Inode_Known     => Volume.Inodes_Known,
            Read_Only            => Volume.Read_Only,
            Read_Only_Known      => Volume.Read_Only_Known,
            Name_Max             => Volume.Name_Max,
            Name_Max_Known       => Volume.Name_Max_Known,
            Removable_Known      => Mount.Removable_Known,
            Removable            => Mount.Removable,
            Ejectable            => False,
            Network_Mount        => Is_Network,
            Remote_Protocol      => To_Unbounded_String (Protocol),
            Offline_Possible     => Is_Network,
            Auth_May_Be_Required => Is_Network and then Auth_May_Be_Required_For (Protocol),
            Latency_Sensitive    => Is_Network,
            Special_Error_Recovery => Is_Network,
            Uses_Platform_Detail =>
              Volume.Known
              or else Volume.Inodes_Known
              or else Volume.Read_Only_Known
              or else Volume.Name_Max_Known
              or else Mount.Found
              or else Mount.Removable_Known);
      end;
   end Root_Volume_Details_For;
