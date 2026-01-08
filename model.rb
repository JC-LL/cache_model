class Memory
  attr_accessor :time_to_process
  def initialize bus_width, random=false
    nb_bytes=2**bus_width
    @data=random ? Array.new(nb_bytes){rand(256)} : @data=Array.new(nb_bytes){0}
    @time_to_process=10
  end

  def read addr
    @data[addr]
  end

  def write addr,data
    @data[addr]=data & 0xff
  end
end

class Line
  attr_accessor :valid,:tag,:bytes
  def initialize nb_bytes
    @nb_bytes=nb_bytes
    @valid=false
    @tag=nil
    @bytes=Array.new(nb_bytes){0}
  end

  def read byte_id
    if byte_id >= @nb_bytes
      raise "ERROR : max number of bytes per line is #{@nb_bytes}. Asked byte #{byte_id}"
    end
    @bytes[byte_id]
  end

  def write byte_id,byte
    @bytes[byte_id]=byte
  end
end

class DirectMappedCache

  attr_accessor :time_to_process

  def initialize bus_width,nb_lines,bloc_size
    @nb_lines,@bloc_size=nb_lines,bloc_size
    @lines=Array.new(nb_lines){Line.new(bloc_size)}
    @nb_bits_offset = @bloc_size.bit_length-1
    @nb_bits_index  = @nb_lines.bit_length-1 # ex : nb_lines=8 =>nb_bits_index=3
    @nb_bits_tag    = bus_width - @nb_bits_offset - @nb_bits_index
    @tag_mask       = (2**@nb_bits_tag-1) << (@nb_bits_index + @nb_bits_offset)
    @index_mask     = (2**@nb_bits_index-1) << @nb_bits_offset
    @offset_mask    = (2**@nb_bits_offset-1)
  end

  def access_to memory
    @mem=memory
  end

  def print_status hit_of_miss,addr
    puts "cache #{hit_of_miss} at 0x#{addr.to_s(16)}"
  end

  def read addr
    puts "trying to read at 0x#{addr.to_s(16)}..."
    tag=(addr & @tag_mask) >> (@nb_bits_index + @nb_bits_offset)
    index=(addr & @index_mask) >> @nb_bits_offset
    offset=addr & @offset_mask
    line=@lines[index]
    if line.valid
      if line.tag==tag
        print_status("hit",addr)
        @time_to_process=1
      else
        print_status("miss",addr)
        load_line(addr,index)
      end
    else
      print_status("miss",addr)
      load_line(addr,index)
    end
    return @lines[index].bytes[offset]
  end

  #=============================================================================
  # Pour une adresse demandée A, le bloc chargé correspond à toutes les adresses alignées
  # sur la taille du bloc qui contiennent A. On oublie donc les bits d'offset :
  #=============================================================================
  def load_line addr,index
    puts "reloading line at index #{index}"
    base_addr=addr & ~@offset_mask # ~ = compl. à 1
    @bloc_size.times do |byte_id| #physically, via bus burst.
      line=@lines[index]
      line.valid=true
      line.tag=(addr & @tag_mask) >> (@nb_bits_index + @nb_bits_offset)
      line.bytes[byte_id]=@mem.read(addr+byte_id)
    end
    @time_to_process=10
  end

  #=============================================================================
  # WARNING : ici simple politique naive de Write-through :
  # Toute écriture met à jour à la fois le cache ET la mémoire principale.
  # Ceci dégrade fortement la performance.
  # TODO : politique write-back.
  #=============================================================================
  def write addr,data
    byte=data & 0xff # le masque assure que la data écrite est un octet
    addr_line=(addr & @index_mask) >> @nb_bits_offset
    offset=addr & @offset_mask
    @lines[addr_line].bytes[offset]=byte
    @mem.write(addr,byte) # write-through le masque assure écriture d'un octet seulement
    @time_to_process=200 # !!!
  end
end

class Program

  def initialize memory
    @mem=memory
    puts "running with memory : #{@mem.class}"
    @time=0
  end

  # ici il faudrait concevoir un générateur d'adresse semi-aléatoire
  # qui représente le comportement de programmes séquentiels (avec quelques sauts etc)
  def run
    # write 0x0,142
    # write 0x1,243
    # write 0x2,144
    # write 0x3,145
    # write 0x4,156
    # write 0x5,157
    read 0x0
    read 0x1
    read 0x2
    read 0x3
    read 0x4
    read 0x5
    puts "total time = #{@time}"
  end

  def read addr
    puts "read 0x#{addr.to_s(16)}"
    data=@mem.read(addr)
    puts "                        -> 0x#{data.to_s(16)}"
    @time+=@mem.time_to_process
  end

  def write addr,data
    puts "write 0x#{addr.to_s(16)} 0x#{data.to_s(16)}"
    @mem.write(addr,data)
    @time+=@mem.time_to_process
  end
end

puts
puts "===== memory access without cache ===="
ram=Memory.new(10,random=true)
prog_1=Program.new(ram)
prog_1.run

puts
puts "==== memory access through direct-mapped cache ===="
cache=DirectMappedCache.new(10,8,4)
cache.access_to ram
prog_2=Program.new(cache)
prog_2.run
