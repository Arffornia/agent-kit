package fr.thegostsniperfr.arffornia.architecture;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

import com.tngtech.archunit.base.DescribedPredicate;
import com.tngtech.archunit.core.domain.JavaAnnotation;
import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;
import com.tngtech.archunit.library.freeze.FreezingArchRule;
import java.util.Set;
import org.junit.jupiter.api.Test;

/**
 * Architecture guards for a NeoForge mod (agent-kit template, templates/guards/neoforge).
 *
 * <p>Each rule is frozen: violations that existed when the guard was adopted are recorded in
 * {@code src/test/resources/archunit_store/} and tolerated; any new violation fails {@code ./gradlew test}.
 * When you fix an old one, ArchUnit removes it from the store: commit that change. Never add
 * entries by hand. Failure messages end with "because ..." which says how to fix it.
 *
 * <p>Adapt the constants below when copying to another mod.
 */
class ArchitectureTest {

    /** Root package of the mod. */
    static final String BASE = "fr.thegostsniperfr.arffornia";

    /** The helper every serverbound payload handler must call (menu open, distance, ownership, unlock state). */
    static final String VALIDATION_HELPER = BASE + ".network.ServerPayloadChecks";

    /** Client-only classes that live outside a {@code client} package (entry points). */
    static final Set<String> CLIENT_ENTRY_POINTS = Set.of(BASE + ".ArfforniaClient");

    /**
     * Classes allowed to build {@code Component.literal} (non-translated text). Keep this tiny: only
     * places that show raw data (ids, numbers, player names) to operators. Everything a player reads goes
     * through lang keys.
     */
    static final Set<String> LITERAL_ALLOW_LIST = Set.of();

    static final JavaClasses CLASSES = new ClassFileImporter()
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
            .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_JARS)
            .importPackages(BASE);

    // ------------------------------------------------------------------ rule 1: client/common split

    static final DescribedPredicate<JavaClass> CLIENT_ONLY = new DescribedPredicate<>("client-only") {
        @Override
        public boolean test(JavaClass c) {
            String outer = c.getName().split("\\$")[0];
            return c.getPackageName().contains(".client")
                    || CLIENT_ENTRY_POINTS.contains(outer)
                    || isClientDist(c)
                    || c.getEnclosingClass().map(ArchitectureTest::isClientDist).orElse(false);
        }
    };

    /** {@code @OnlyIn(Dist.CLIENT)} or {@code @EventBusSubscriber(value = Dist.CLIENT)}. */
    static boolean isClientDist(JavaClass c) {
        for (JavaAnnotation<JavaClass> a : c.getAnnotations()) {
            String type = a.getRawType().getName();
            if (type.endsWith(".OnlyIn") || type.endsWith(".EventBusSubscriber")) {
                Object value = a.get("value").orElse(null);
                if (value != null && (value instanceof Object[] arr ? java.util.Arrays.toString(arr) : String.valueOf(value)).contains("CLIENT")) {
                    return true;
                }
            }
        }
        return false;
    }

    @Test
    void commonCodeDoesNotReferenceClientOnlyCode() {
        ArchRule rule = noClasses()
                .that(DescribedPredicate.not(CLIENT_ONLY))
                .should()
                .dependOnClassesThat()
                .resideInAnyPackage("net.minecraft.client..", "com.mojang.blaze3d..", BASE + ".client..")
                .because("a dedicated server has no client classes and crashes with NoClassDefFoundError when common code "
                        + "touches them. Fix: move the client part into a class under " + BASE + ".client (or a "
                        + "@EventBusSubscriber(value = Dist.CLIENT) class) and reach it from common code only through "
                        + "a payload handler or an interface whose client implementation is registered from the client entry point. "
                        + "JEI/compat classes that need screens: put the screen-specific part in a client subpackage.");
        FreezingArchRule.freeze(rule).check(CLASSES);
    }

    // ------------------------------------------------------------------ rule 2: payload validation

    static ArchCondition<JavaClass> callTheValidationHelper() {
        return new ArchCondition<>("call " + VALIDATION_HELPER) {
            @Override
            public void check(JavaClass c, ConditionEvents events) {
                boolean calls = c.getAccessesFromSelf().stream()
                        .anyMatch(access -> access.getTargetOwner().getName().equals(VALIDATION_HELPER));
                if (!calls) {
                    events.add(SimpleConditionEvent.violated(c, c.getName() + " handles a serverbound payload without calling "
                            + VALIDATION_HELPER.substring(VALIDATION_HELPER.lastIndexOf('.') + 1)));
                }
            }
        };
    }

    @Test
    void serverboundPayloadHandlersValidateOnTheServer() {
        ArchRule rule = classes()
                .that().resideInAPackage(BASE + ".network..")
                .and().haveSimpleNameStartingWith("Serverbound")
                .and().areNotNestedClasses()
                .should(callTheValidationHelper())
                .because("a modified client can send any payload at any time. Fix: in the handler, before touching the world, "
                        + "call " + VALIDATION_HELPER + " (menu open and matching, distance <= 8 blocks, ownership, unlock state) "
                        + "and return early when it fails; add the missing check to that helper rather than inlining it.");
        FreezingArchRule.freeze(rule).check(CLASSES);
    }

    // ------------------------------------------------------------------ rule 3: translatable text

    @Test
    void playerFacingTextIsTranslatable() {
        ArchRule rule = noClasses()
                .that(DescribedPredicate.not(new DescribedPredicate<JavaClass>("on the literal allow-list") {
                    @Override
                    public boolean test(JavaClass c) {
                        return LITERAL_ALLOW_LIST.contains(c.getName().split("\\$")[0]);
                    }
                }))
                .should()
                .callMethod("net.minecraft.network.chat.Component", "literal", "java.lang.String")
                .because("players read the mod in English and French. Fix: use Component.translatable(\"<area>.arffornia.<key>\", args...) "
                        + "and add the key to assets/arffornia/lang/en_us.json and fr_fr.json; style with ChatFormatting, not "
                        + "section-sign codes. Raw data (numbers, names) goes in as translatable args.");
        FreezingArchRule.freeze(rule).check(CLASSES);
    }
}
