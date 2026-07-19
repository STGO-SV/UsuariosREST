package com.usuarios.UsuariosRest;

import com.usuarios.UsuariosRest.models.UsuarioModel;
import com.usuarios.UsuariosRest.repositories.IUsuarioRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@ActiveProfiles("test")
@AutoConfigureMockMvc
class UsuariosRestApplicationTests {
	@Autowired
	private IUsuarioRepository usuarioRepository;
	@Autowired
	private MockMvc mockMvc;
	@Autowired
	private ObjectMapper objectMapper;

	@BeforeEach
	void cleanDatabase() {
		usuarioRepository.deleteAll();
	}

	@Test
	void contextLoads() {
	}

	@Test
	void repositorySavesAndFindsUser() {
		UsuarioModel usuario = new UsuarioModel();
		usuario.setFirstName("Usuario");
		usuario.setLastName("Prueba");
		usuario.setEmail("usuario.prueba@example.test");

		UsuarioModel saved = usuarioRepository.saveAndFlush(usuario);
		Optional<UsuarioModel> found = usuarioRepository.findById(saved.getId());

		assertThat(saved.getId()).isPositive();
		assertThat(found).isPresent();
		assertThat(found.orElseThrow().getEmail()).isEqualTo("usuario.prueba@example.test");
	}

	@Test
	void repositoryRejectsDuplicateEmail() {
		UsuarioModel first = new UsuarioModel();
		first.setFirstName("Primero");
		first.setLastName("Prueba");
		first.setEmail("correo.unico@example.test");
		usuarioRepository.saveAndFlush(first);

		UsuarioModel duplicate = new UsuarioModel();
		duplicate.setFirstName("Segundo");
		duplicate.setLastName("Prueba");
		duplicate.setEmail("correo.unico@example.test");

		assertThatThrownBy(() -> usuarioRepository.saveAndFlush(duplicate))
				.isInstanceOf(DataIntegrityViolationException.class);
	}

	@Test
	void controllerSupportsCrudFlow() throws Exception {
		String requestBody = """
				{"firstName":"Controlador","lastName":"Prueba","email":"controlador@example.test"}
				""";

		String createdJson = mockMvc.perform(post("/user")
					.contentType(MediaType.APPLICATION_JSON)
					.content(requestBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.email").value("controlador@example.test"))
				.andReturn().getResponse().getContentAsString();
		JsonNode created = objectMapper.readTree(createdJson);
		long id = created.get("id").asLong();

		mockMvc.perform(get("/user/{id}", id))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.firstName").value("Controlador"));

		mockMvc.perform(put("/user/{id}", id)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"firstName":"Actualizado","lastName":"Prueba","email":"controlador@example.test"}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.firstName").value("Actualizado"));

		mockMvc.perform(delete("/user/{id}", id))
				.andExpect(status().isOk());

		mockMvc.perform(get("/user/{id}", id))
				.andExpect(status().isBadRequest());
	}

}
