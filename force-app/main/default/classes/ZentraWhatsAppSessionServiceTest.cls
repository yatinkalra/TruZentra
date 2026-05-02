@IsTest
private class ZentraWhatsAppSessionServiceTest {

    @IsTest
    static void testGetCustomerPhone_WithFallback() {
        ZentraWhatsAppSessionService.PhoneRequest req = new ZentraWhatsAppSessionService.PhoneRequest();
        req.fallbackPhone = '+919876543210';

        Test.startTest();
        List<ZentraWhatsAppSessionService.PhoneResponse> responses =
            ZentraWhatsAppSessionService.getCustomerPhone(
                new List<ZentraWhatsAppSessionService.PhoneRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(true, responses[0].success);
        System.assertEquals('+919876543210', responses[0].phoneNumber);
        System.assertEquals(false, responses[0].detectedFromWhatsApp);
    }

    @IsTest
    static void testGetCustomerPhone_NoPhone() {
        ZentraWhatsAppSessionService.PhoneRequest req = new ZentraWhatsAppSessionService.PhoneRequest();

        Test.startTest();
        List<ZentraWhatsAppSessionService.PhoneResponse> responses =
            ZentraWhatsAppSessionService.getCustomerPhone(
                new List<ZentraWhatsAppSessionService.PhoneRequest>{ req }
            );
        Test.stopTest();

        System.assertEquals(false, responses[0].success);
        System.assertEquals(null, responses[0].phoneNumber);
    }

    @IsTest
    static void testCleanPhoneNumber_WhatsAppPrefix() {
        String result = ZentraWhatsAppSessionService.cleanPhoneNumber('whatsapp:+919876543210');
        System.assertEquals('+919876543210', result);
    }

    @IsTest
    static void testCleanPhoneNumber_PlainNumber() {
        String result = ZentraWhatsAppSessionService.cleanPhoneNumber('+919876543210');
        System.assertEquals('+919876543210', result);
    }

    @IsTest
    static void testCleanPhoneNumber_Blank() {
        System.assertEquals(null, ZentraWhatsAppSessionService.cleanPhoneNumber(null));
        System.assertEquals(null, ZentraWhatsAppSessionService.cleanPhoneNumber(''));
    }

    @IsTest
    static void testCleanPhoneNumber_NoPlus() {
        String result = ZentraWhatsAppSessionService.cleanPhoneNumber('919876543210');
        System.assertEquals('919876543210', result);
    }
}
