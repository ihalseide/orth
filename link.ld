# Desired Layout in memory
# * 0x0-0x8000 : parameter and return stacks
# * 0x8000...0x8000+X : core code
# * 0x8000+X...0x8000+X+Y : read-only data
# * 0x8000+X+Y... : data (heap)

