with Ada.Strings.Unbounded;

package body Files.Preview_Decoder is
   use Ada.Strings.Unbounded;

   protected Slot is
      procedure Put (Path : String; Size : Positive);
      procedure Next (Found : out Boolean; Path : out Unbounded_String; Size : out Positive);
      procedure Deliver (Path : Unbounded_String; Image : Files.Images.Decoded_Image);
      procedure Collect (Path : String; Image : out Files.Images.Decoded_Image; Ready : out Boolean);
      function Waiting return Boolean;
   private
      Pending       : Boolean := False;
      Pending_Path  : Unbounded_String;
      Pending_Size  : Positive := 1;
      Done          : Boolean := False;
      Done_Path     : Unbounded_String;
      Done_Image    : Files.Images.Decoded_Image;
   end Slot;

   protected body Slot is
      procedure Put (Path : String; Size : Positive) is
      begin
         Pending := True;
         Pending_Path := To_Unbounded_String (Path);
         Pending_Size := Size;
         --  A result for another file is stale now.
         if Done and then Done_Path /= Pending_Path then
            Done := False;
            Done_Image := (others => <>);
         end if;
      end Put;

      procedure Next (Found : out Boolean; Path : out Unbounded_String; Size : out Positive) is
      begin
         Found := Pending;
         Path := Pending_Path;
         Size := Pending_Size;
         Pending := False;
      end Next;

      procedure Deliver (Path : Unbounded_String; Image : Files.Images.Decoded_Image) is
      begin
         --  Kept only while nothing newer has been asked for.
         if not Pending or else Pending_Path = Path then
            Done := True;
            Done_Path := Path;
            Done_Image := Image;
         end if;
      end Deliver;

      procedure Collect (Path : String; Image : out Files.Images.Decoded_Image; Ready : out Boolean) is
      begin
         Ready := Done and then To_String (Done_Path) = Path;
         if Ready then
            Image := Done_Image;
            Done := False;
            Done_Image := (others => <>);
         else
            Image := (others => <>);
         end if;
      end Collect;

      function Waiting return Boolean is (Pending);
   end Slot;

   task Worker is
      entry Wake;
   end Worker;

   task body Worker is
      Found : Boolean;
      Path  : Unbounded_String;
      Size  : Positive;
   begin
      loop
         select
            accept Wake;
         or
            terminate;
         end select;
         loop
            Slot.Next (Found, Path, Size);
            exit when not Found;
            declare
               Image : Files.Images.Decoded_Image;
            begin
               begin
                  Image := Files.Images.Decode_Image_To_Pixels (To_String (Path), Size);
               exception
                  when others =>
                     Image := (others => <>);
               end;
               Slot.Deliver (Path, Image);
            end;
         end loop;
      end loop;
   end Worker;

   --  Wake the worker if it is waiting; when it is busy it takes the request
   --  after the current one.
   procedure Kick is
   begin
      select
         Worker.Wake;
      else
         null;
      end select;
   end Kick;

   procedure Request (Path : String; Size : Positive) is
   begin
      Slot.Put (Path, Size);
      Kick;
   end Request;

   procedure Take
     (Path  : String;
      Image : out Files.Images.Decoded_Image;
      Ready : out Boolean) is
   begin
      Slot.Collect (Path, Image, Ready);
      --  A wake-up can be missed between the worker's last look and its
      --  return to waiting: asking again costs nothing.
      if not Ready and then Slot.Waiting then
         Kick;
      end if;
   end Take;

end Files.Preview_Decoder;
