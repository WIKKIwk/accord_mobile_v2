#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>
#include <CoreFoundation/CoreFoundation.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void release_device(IOUSBDeviceInterface **device) {
    if (device == NULL) return;
    (*device)->USBDeviceClose(device);
    (*device)->Release(device);
}

static const char *known_printer_kind(uint16_t vendor_id,
                                      uint16_t product_id) {
    if (vendor_id == 0x195f && product_id == 0x0001) return "godex";
    if (vendor_id == 0x0a5f) return "zebra";
    return NULL;
}

static int detect_known_printer(uint16_t *out_vendor, uint16_t *out_product,
                                const char **out_kind) {
    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (matching == NULL) return 1;

    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t result = IOServiceGetMatchingServices(
        kIOMainPortDefault, matching, &iterator);
    if (result != KERN_SUCCESS) return 2;

    io_service_t service;
    while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        IOCFPlugInInterface **plugin = NULL;
        SInt32 score = 0;
        result = IOCreatePlugInInterfaceForService(
            service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
            &plugin, &score);
        IOObjectRelease(service);
        if (result != KERN_SUCCESS || plugin == NULL) continue;

        IOUSBDeviceInterface **device = NULL;
        HRESULT query = (*plugin)->QueryInterface(
            plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
            (LPVOID *)&device);
        (*plugin)->Release(plugin);
        if (query != S_OK || device == NULL) continue;

        UInt16 vendor = 0;
        UInt16 product = 0;
        (*device)->GetDeviceVendor(device, &vendor);
        (*device)->GetDeviceProduct(device, &product);
        const char *kind = known_printer_kind(vendor, product);
        (*device)->Release(device);
        if (kind == NULL) continue;

        IOObjectRelease(iterator);
        *out_vendor = vendor;
        *out_product = product;
        *out_kind = kind;
        return 0;
    }

    IOObjectRelease(iterator);
    return 3;
}

static int find_device(uint16_t vendor_id, uint16_t product_id,
                       IOUSBDeviceInterface ***out_device) {
    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (matching == NULL) return 1;

    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t result = IOServiceGetMatchingServices(
        kIOMainPortDefault, matching, &iterator);
    if (result != KERN_SUCCESS) return 2;

    io_service_t service;
    while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        IOCFPlugInInterface **plugin = NULL;
        SInt32 score = 0;
        result = IOCreatePlugInInterfaceForService(
            service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
            &plugin, &score);
        IOObjectRelease(service);
        if (result != KERN_SUCCESS || plugin == NULL) continue;

        IOUSBDeviceInterface **device = NULL;
        HRESULT query = (*plugin)->QueryInterface(
            plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID),
            (LPVOID *)&device);
        (*plugin)->Release(plugin);
        if (query != S_OK || device == NULL) continue;

        UInt16 found_vendor = 0;
        UInt16 found_product = 0;
        (*device)->GetDeviceVendor(device, &found_vendor);
        (*device)->GetDeviceProduct(device, &found_product);
        if (found_vendor == vendor_id && found_product == product_id) {
            IOIteratorReset(iterator);
            IOObjectRelease(iterator);
            *out_device = device;
            return 0;
        }
        (*device)->Release(device);
    }

    IOObjectRelease(iterator);
    return 3;
}

static int write_payload(IOUSBDeviceInterface **device, const uint8_t *data,
                         size_t length) {
    UInt8 configuration_count = 0;
    kern_return_t result = (*device)->GetNumberOfConfigurations(
        device, &configuration_count);
    if (result != KERN_SUCCESS || configuration_count == 0) return 10;

    IOUSBConfigurationDescriptorPtr configuration = NULL;
    result = (*device)->GetConfigurationDescriptorPtr(device, 0, &configuration);
    if (result != KERN_SUCCESS || configuration == NULL) return 11;

    result = (*device)->USBDeviceOpen(device);
    if (result != KERN_SUCCESS && result != kIOReturnExclusiveAccess) return 12;
    result = (*device)->SetConfiguration(device, configuration->bConfigurationValue);
    if (result != KERN_SUCCESS) {
        release_device(device);
        return 13;
    }

    IOUSBFindInterfaceRequest request = {
        kIOUSBFindInterfaceDontCare,
        kIOUSBFindInterfaceDontCare,
        kIOUSBFindInterfaceDontCare,
        kIOUSBFindInterfaceDontCare,
    };
    io_iterator_t iterator = IO_OBJECT_NULL;
    result = (*device)->CreateInterfaceIterator(device, &request, &iterator);
    if (result != KERN_SUCCESS) {
        release_device(device);
        return 14;
    }

    int status = 15;
    io_service_t service;
    unsigned interface_count = 0;
    while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        interface_count++;
        IOCFPlugInInterface **plugin = NULL;
        SInt32 score = 0;
        result = IOCreatePlugInInterfaceForService(
            service, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID,
            &plugin, &score);
        IOObjectRelease(service);
        if (result != KERN_SUCCESS || plugin == NULL) continue;

        IOUSBInterfaceInterface **interface = NULL;
        HRESULT query = (*plugin)->QueryInterface(
            plugin, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID),
            (LPVOID *)&interface);
        (*plugin)->Release(plugin);
        if (query != S_OK || interface == NULL) continue;

        result = (*interface)->USBInterfaceOpen(interface);
        if (result != KERN_SUCCESS && result != kIOReturnExclusiveAccess) {
            (*interface)->Release(interface);
            status = 16;
            continue;
        }

        UInt8 endpoint_count = 0;
        (*interface)->GetNumEndpoints(interface, &endpoint_count);
        fprintf(stderr, "USB interface candidate: endpoints=%u\n", endpoint_count);
        UInt8 bulk_out_pipe = 0;
        UInt16 max_packet = 0;
        for (UInt8 pipe = 1; pipe <= endpoint_count; pipe++) {
            UInt8 direction = 0;
            UInt8 number = 0;
            UInt8 transfer_type = 0;
            UInt16 packet = 0;
            UInt8 interval = 0;
            result = (*interface)->GetPipeProperties(
                interface, pipe, &direction, &number, &transfer_type, &packet,
                &interval);
            fprintf(stderr,
                    "  pipe=%u result=0x%08x direction=%u number=%u type=%u packet=%u\n",
                    pipe, result, direction, number, transfer_type, packet);
            if (result == KERN_SUCCESS &&
                direction == kUSBOut && transfer_type == kUSBBulk) {
                bulk_out_pipe = pipe;
                max_packet = packet == 0 ? 64 : packet;
                break;
            }
        }
        if (bulk_out_pipe == 0) {
            (*interface)->USBInterfaceClose(interface);
            (*interface)->Release(interface);
            continue;
        }

        size_t offset = 0;
        status = 0;
        while (offset < length) {
            UInt32 chunk = (UInt32)((length - offset) < max_packet
                                        ? (length - offset)
                                        : max_packet);
            result = (*interface)->WritePipe(interface, bulk_out_pipe,
                                             (void *)(data + offset), chunk);
            if (result != KERN_SUCCESS) {
                fprintf(stderr, "WritePipe failed at %zu: 0x%08x\n", offset,
                        result);
                status = 17;
                break;
            }
            offset += chunk;
        }
        if (status == 0) {
            printf("sent %zu bytes via bulk-out pipe %u (max packet %u)\n",
                   length, bulk_out_pipe, max_packet);
        }
        (*interface)->USBInterfaceClose(interface);
        (*interface)->Release(interface);
        if (status == 0) break;
    }

    IOObjectRelease(iterator);
    if (status == 15) {
        fprintf(stderr, "no bulk-out interface found (candidates=%u)\n",
                interface_count);
    }
    release_device(device);
    return status;
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "--detect") == 0) {
        uint16_t vendor = 0;
        uint16_t product = 0;
        const char *kind = NULL;
        int status = detect_known_printer(&vendor, &product, &kind);
        if (status != 0) {
            fprintf(stderr, "GoDEX or Zebra USB printer not found (status %d)\n",
                    status);
            return status;
        }
        printf("%s %04x %04x\n", kind, vendor, product);
        return 0;
    }
    if (argc != 4) {
        fprintf(stderr,
                "usage: %s --detect | <vid> <pid> <payload.bin>\n",
                argv[0]);
        return 2;
    }
    char *end = NULL;
    unsigned long vendor = strtoul(argv[1], &end, 16);
    if (*end != '\0' || vendor > UINT16_MAX) return 2;
    unsigned long product = strtoul(argv[2], &end, 16);
    if (*end != '\0' || product > UINT16_MAX) return 2;

    FILE *file = fopen(argv[3], "rb");
    if (file == NULL) {
        fprintf(stderr, "cannot open %s: %s\n", argv[3], strerror(errno));
        return 3;
    }
    fseek(file, 0, SEEK_END);
    long size = ftell(file);
    fseek(file, 0, SEEK_SET);
    if (size <= 0) {
        fclose(file);
        return 4;
    }
    uint8_t *data = malloc((size_t)size);
    if (data == NULL || fread(data, 1, (size_t)size, file) != (size_t)size) {
        fclose(file);
        free(data);
        return 5;
    }
    fclose(file);

    IOUSBDeviceInterface **device = NULL;
    int status = find_device((uint16_t)vendor, (uint16_t)product, &device);
    if (status != 0) {
        fprintf(stderr, "USB device %04lx:%04lx not found (status %d)\n",
                vendor, product, status);
        free(data);
        return status;
    }
    status = write_payload(device, data, (size_t)size);
    free(data);
    return status;
}
